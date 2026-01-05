#!/usr/bin/env python3
"""
Luanti Treasure Placement Tool
Places puzzle chests, beacons, poles, and treasure at admin's position via MTUI API.

Usage:
    ./place-treasure.py --action=puzzlechest --mtuiurl=http://192.168.1.223:8000 --password=secret
    ./place-treasure.py --action=beacon --mtuiurl=... --password=... --color=blue
    ./place-treasure.py --action=pole --mtuiurl=... --password=... --color=red --height=20
    ./place-treasure.py --action=treasure --mtuiurl=... --password=... --tier=medium
    ./place-treasure.py --action=quiztrail --mtuiurl=... --password=... --length=5

For triggerhappy daemon integration on Raspberry Pi.
"""

import argparse
import json
import logging
import os
import random
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any

# Default paths
DEFAULT_QUESTIONS_DB = Path(__file__).parent / "questions.json"
DEFAULT_HISTORY_FILE = Path.home() / ".luanti-treasure-history.json"
DEFAULT_LOG_FILE = Path.home() / ".luanti-treasure.log"

# Available colors for poles/beacons
COLORS = ["red", "blue", "yellow", "green", "white", "orange"]
BEACON_COLORS = COLORS + ["gold", "diamond"]

# Difficulty to tier mapping
DIFFICULTY_TO_TIER = {
    "easy": "small",
    "medium": "medium",
    "hard": "big",
    "expert": "epic"
}

# Setup logging
def setup_logging(log_file: Path, verbose: bool = False):
    """Setup logging to file and optionally console."""
    level = logging.DEBUG if verbose else logging.INFO

    handlers = [logging.FileHandler(log_file)]
    if verbose:
        handlers.append(logging.StreamHandler())

    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=handlers
    )

class QuestionDatabase:
    """Manages the question database and history tracking."""

    def __init__(self, db_path: Path, history_path: Path):
        self.db_path = db_path
        self.history_path = history_path
        self.questions: Dict[str, List[Dict]] = {}
        self.history: Dict[str, Any] = {"used_questions": [], "stats": {}}

        self._load_database()
        self._load_history()

    def _load_database(self):
        """Load questions from JSON database."""
        try:
            with open(self.db_path, 'r') as f:
                data = json.load(f)
                # Extract questions by difficulty
                for difficulty in ["easy", "medium", "hard", "expert"]:
                    self.questions[difficulty] = data.get(difficulty, [])
            logging.info(f"Loaded {sum(len(q) for q in self.questions.values())} questions from {self.db_path}")
        except FileNotFoundError:
            logging.error(f"Questions database not found: {self.db_path}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            logging.error(f"Invalid JSON in questions database: {e}")
            sys.exit(1)

    def _load_history(self):
        """Load question usage history."""
        try:
            if self.history_path.exists():
                with open(self.history_path, 'r') as f:
                    self.history = json.load(f)
                logging.info(f"Loaded history with {len(self.history.get('used_questions', []))} used questions")
            else:
                logging.info("No history file found, starting fresh")
        except (json.JSONDecodeError, IOError) as e:
            logging.warning(f"Could not load history, starting fresh: {e}")
            self.history = {"used_questions": [], "stats": {}}

    def _save_history(self):
        """Save question usage history."""
        try:
            self.history["last_updated"] = datetime.now().isoformat()
            with open(self.history_path, 'w') as f:
                json.dump(self.history, f, indent=2)
            logging.debug(f"Saved history to {self.history_path}")
        except IOError as e:
            logging.error(f"Could not save history: {e}")

    def get_random_question(self, category: Optional[str] = None, difficulty: Optional[str] = None) -> Optional[Dict]:
        """
        Get a random unused question.

        Args:
            category: Filter by category (math, science, geography, nature, history, general)
            difficulty: Filter by difficulty (easy, medium, hard, expert). If None, random.

        Returns:
            Question dict with id, q, a, hint, category, difficulty fields
        """
        used_ids = set(self.history.get("used_questions", []))

        # Determine difficulty order to try
        if difficulty is None:
            # Random difficulty with weighted distribution, but we'll try others if no match
            difficulties_to_try = random.sample(["easy", "medium", "hard", "expert"], 4)
            # Weight toward medium/easy by trying them first more often
            if random.random() < 0.7:
                difficulties_to_try = ["medium", "easy", "hard", "expert"]
        else:
            difficulties_to_try = [difficulty]

        available = []
        chosen_difficulty = None

        for diff in difficulties_to_try:
            # Get available questions for this difficulty
            pool = self.questions.get(diff, [])

            # Filter by category if specified
            if category and category != "random":
                pool = [q for q in pool if q.get("category") == category]

            # Filter out used questions
            pool = [q for q in pool if q.get("id") not in used_ids]

            if pool:
                available = pool
                chosen_difficulty = diff
                break

        if not available:
            # All questions used for this category, reset history
            logging.warning(f"All questions used for category={category}, resetting history")
            self.history["used_questions"] = []
            self._save_history()

            # Try again with fresh history
            for diff in difficulties_to_try:
                pool = self.questions.get(diff, [])
                if category and category != "random":
                    pool = [q for q in pool if q.get("category") == category]
                if pool:
                    available = pool
                    chosen_difficulty = diff
                    break

        if not available:
            logging.error(f"No questions available for category={category}")
            return None

        difficulty = chosen_difficulty

        # Select random question
        question = random.choice(available)

        # Mark as used
        self.history["used_questions"].append(question["id"])

        # Update stats
        stats = self.history.setdefault("stats", {})
        stats["total_placed"] = stats.get("total_placed", 0) + 1
        by_category = stats.setdefault("by_category", {})
        by_category[question["category"]] = by_category.get(question["category"], 0) + 1
        by_difficulty = stats.setdefault("by_difficulty", {})
        by_difficulty[difficulty] = by_difficulty.get(difficulty, 0) + 1

        self._save_history()

        # Add difficulty to returned question
        question_with_difficulty = question.copy()
        question_with_difficulty["difficulty"] = difficulty

        return question_with_difficulty

    def reset_history(self):
        """Reset all question history."""
        self.history = {"used_questions": [], "stats": {}}
        self._save_history()
        logging.info("Question history reset")


class LuantiCLI:
    """Interface to luanti-cli.sh for executing game commands."""

    def __init__(self, mtui_url: str, password: str, cli_path: Optional[Path] = None):
        self.mtui_url = mtui_url
        self.password = password
        self.cli_path = cli_path or (Path(__file__).parent / "luanti-cli.sh")

        if not self.cli_path.exists():
            logging.error(f"luanti-cli.sh not found at {self.cli_path}")
            sys.exit(1)

    def execute(self, command: str, dry_run: bool = False) -> tuple[bool, str]:
        """
        Execute a Luanti command via CLI.

        Args:
            command: The /command to execute (e.g., "/puzzlechest medium ...")
            dry_run: If True, just print the command without executing

        Returns:
            Tuple of (success: bool, output: str)
        """
        full_cmd = [
            str(self.cli_path),
            f"--url={self.mtui_url}",
            f"--password={self.password}",
            f"--command={command}"
        ]

        cmd_str = ' '.join(full_cmd)
        # Hide password in logs
        safe_cmd = cmd_str.replace(self.password, "****")

        if dry_run:
            logging.info(f"[DRY RUN] Would execute: {safe_cmd}")
            print(f"[DRY RUN] {safe_cmd}")
            return True, "[DRY RUN]"

        logging.info(f"Executing: {safe_cmd}")

        try:
            result = subprocess.run(
                full_cmd,
                capture_output=True,
                text=True,
                timeout=30
            )

            output = result.stdout + result.stderr
            success = result.returncode == 0

            if success:
                logging.info(f"Command successful: {output[:200]}")
            else:
                logging.error(f"Command failed: {output}")

            return success, output

        except subprocess.TimeoutExpired:
            logging.error("Command timed out")
            return False, "Timeout"
        except Exception as e:
            logging.error(f"Command execution failed: {e}")
            return False, str(e)


class TreasurePlacer:
    """Main class for placing treasures in Luanti."""

    def __init__(self, cli: LuantiCLI, question_db: QuestionDatabase):
        self.cli = cli
        self.question_db = question_db

    def place_puzzlechest(self, category: Optional[str] = None,
                          difficulty: Optional[str] = None,
                          dry_run: bool = False,
                          announce: bool = True) -> bool:
        """
        Place a puzzle chest with a random question at admin's position.

        Args:
            category: Question category filter
            difficulty: Question difficulty (determines chest tier)
            dry_run: Preview without executing
            announce: Broadcast achievement when solved
        """
        question = self.question_db.get_random_question(category, difficulty)
        if not question:
            logging.error("No question available")
            return False

        tier = DIFFICULTY_TO_TIER.get(question["difficulty"], "medium")

        # Build the command - question with hint in parentheses
        q_text = question["q"]
        if question.get("hint"):
            q_text = f"{q_text} (Hint: {question['hint']})"

        # Escape special characters for shell
        q_text = q_text.replace("'", "\\'")
        answer = question["a"].replace("'", "\\'")

        command = f"/puzzlechest {tier} {q_text} | {answer}"

        logging.info(f"Placing {tier} puzzle chest - Category: {question['category']}, Q: {question['q']}")

        success, output = self.cli.execute(command, dry_run)

        if success and not dry_run:
            print(f"Placed {tier} puzzle chest ({question['category']}): {question['q'][:50]}...")

        return success

    def place_beacon(self, color: Optional[str] = None, dry_run: bool = False) -> bool:
        """Place a beacon at admin's position."""
        if color is None or color == "random":
            color = random.choice(BEACON_COLORS)

        if color not in BEACON_COLORS:
            logging.error(f"Invalid beacon color: {color}. Valid: {BEACON_COLORS}")
            return False

        command = f"/beacon {color}"
        logging.info(f"Placing {color} beacon")

        success, output = self.cli.execute(command, dry_run)

        if success and not dry_run:
            print(f"Placed {color} beacon")

        return success

    def place_pole(self, color: Optional[str] = None, height: int = 20,
                   dry_run: bool = False) -> bool:
        """Place a pole at admin's position."""
        if color is None or color == "random":
            color = random.choice(COLORS)

        if color not in COLORS + ["gold", "diamond", "glow"]:
            logging.error(f"Invalid pole color: {color}")
            return False

        command = f"/pole {color} {height}"
        logging.info(f"Placing {color} pole (height={height})")

        success, output = self.cli.execute(command, dry_run)

        if success and not dry_run:
            print(f"Placed {color} pole (height {height})")

        return success

    def place_treasure(self, tier: Optional[str] = None, dry_run: bool = False) -> bool:
        """Place a simple treasure chest at admin's position."""
        if tier is None or tier == "random":
            tier = random.choice(["small", "medium", "big", "epic"])

        valid_tiers = ["small", "medium", "big", "epic"]
        if tier not in valid_tiers:
            logging.error(f"Invalid tier: {tier}. Valid: {valid_tiers}")
            return False

        command = f"/treasure {tier}"
        logging.info(f"Placing {tier} treasure chest")

        success, output = self.cli.execute(command, dry_run)

        if success and not dry_run:
            print(f"Placed {tier} treasure chest")

        return success

    def place_quiztrail(self, length: int = 5, category: Optional[str] = None,
                        dry_run: bool = False) -> bool:
        """
        Place a connected trail of puzzle chests with progressive difficulty.

        Creates: beacon -> puzzle -> sign -> puzzle -> ... -> epic puzzle
        """
        if length < 2:
            length = 2
        if length > 10:
            length = 10

        logging.info(f"Creating quiz trail with {length} puzzles")

        # Place starting beacon
        success = self.place_beacon(color="blue", dry_run=dry_run)
        if not success:
            return False

        # Place starting sign
        sign_cmd = "/placetext QUIZ TRAIL|Answer puzzles|to find treasure!"
        self.cli.execute(sign_cmd, dry_run)

        # Determine difficulty progression
        difficulties = []
        for i in range(length):
            progress = i / (length - 1) if length > 1 else 0
            if progress < 0.3:
                difficulties.append("easy")
            elif progress < 0.6:
                difficulties.append("medium")
            elif progress < 0.9:
                difficulties.append("hard")
            else:
                difficulties.append("expert")

        # Place puzzles (admin walks to each location)
        for i, diff in enumerate(difficulties):
            # Wait message
            if not dry_run:
                print(f"\n[{i+1}/{length}] Walk to next location, then press Enter...")
                if i < length - 1:
                    input()

            # Place puzzle
            success = self.place_puzzlechest(category=category, difficulty=diff, dry_run=dry_run)
            if not success:
                logging.error(f"Failed to place puzzle {i+1}")
                continue

            # Place directional sign (except for last one)
            if i < length - 1 and not dry_run:
                directions = ["Look NORTH", "Look EAST", "Look SOUTH", "Look WEST", "Keep exploring"]
                sign_cmd = f"/placetext CLUE {i+1}|{random.choice(directions)}|for next puzzle!"
                self.cli.execute(sign_cmd, dry_run)

        # Place final beacon
        if not dry_run:
            print("\nWalk to final treasure location, then press Enter...")
            input()

        self.place_beacon(color="gold", dry_run=dry_run)

        # Announce
        announce_cmd = "/announce A Quiz Trail has been created! Find the blue beacon to start!"
        self.cli.execute(announce_cmd, dry_run)

        print(f"\nQuiz trail created with {length} puzzles!")
        return True

    def announce_achievement(self, player: str, category: str, dry_run: bool = False) -> bool:
        """Broadcast achievement when player solves puzzle."""
        messages = [
            f"{player} just solved a {category.upper()} puzzle!",
            f"Brain power! {player} cracked a {category} question!",
            f"{player} is on fire with {category}!",
        ]
        command = f"/announce {random.choice(messages)}"
        return self.cli.execute(command, dry_run)[0]


def generate_ai_question(endpoint: str, api_key: str, category: str = "random") -> Optional[Dict]:
    """
    Generate a question using AI API (OpenAI-compatible).

    Args:
        endpoint: AI API endpoint (e.g., https://api.openai.com/v1)
        api_key: API key
        category: Question category

    Returns:
        Question dict or None on failure
    """
    try:
        import requests
    except ImportError:
        logging.error("requests library required for AI mode: pip install requests")
        return None

    if category == "random":
        category = random.choice(["math", "science", "geography", "nature", "history", "general"])

    prompt = f"""Generate a trivia question for kids aged 8-14 in the category: {category}

Requirements:
- Age-appropriate difficulty
- Clear, unambiguous answer (1-3 words)
- Educational value
- Include a helpful hint

Respond in this exact JSON format:
{{"q": "question text", "a": "answer", "hint": "helpful hint", "difficulty": "easy|medium|hard|expert"}}

Only output the JSON, nothing else."""

    try:
        response = requests.post(
            f"{endpoint}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": "gpt-3.5-turbo",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 200
            },
            timeout=30
        )

        if response.status_code == 200:
            content = response.json()["choices"][0]["message"]["content"]
            question = json.loads(content)
            question["category"] = category
            question["id"] = f"ai_{datetime.now().strftime('%Y%m%d%H%M%S')}"
            logging.info(f"AI generated question: {question['q']}")
            return question
        else:
            logging.error(f"AI API error: {response.status_code} - {response.text}")
            return None

    except Exception as e:
        logging.error(f"AI question generation failed: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(
        description="Luanti Treasure Placement Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Place puzzle chest with random question
  %(prog)s --action=puzzlechest --mtuiurl=http://192.168.1.223:8000 --password=secret

  # Place math-only puzzle chest
  %(prog)s --action=puzzlechest --mtuiurl=... --password=... --category=math

  # Place blue beacon
  %(prog)s --action=beacon --mtuiurl=... --password=... --color=blue

  # Place pole with random color
  %(prog)s --action=pole --mtuiurl=... --password=... --height=25

  # Create quiz trail with 5 puzzles
  %(prog)s --action=quiztrail --mtuiurl=... --password=... --length=5

  # Dry run - preview commands
  %(prog)s --action=puzzlechest --mtuiurl=... --password=... --dryrun
"""
    )

    # Required arguments
    parser.add_argument("--action", required=True,
                        choices=["puzzlechest", "beacon", "pole", "treasure", "quiztrail"],
                        help="Action to perform")
    parser.add_argument("--mtuiurl", required=True,
                        help="MTUI URL (e.g., http://192.168.1.223:8000)")
    parser.add_argument("--password", required=True,
                        help="Admin password for MTUI")

    # Optional arguments
    parser.add_argument("--category", default="random",
                        choices=["random", "math", "science", "geography", "nature", "history", "general"],
                        help="Question category (default: random)")
    parser.add_argument("--difficulty", default=None,
                        choices=["easy", "medium", "hard", "expert"],
                        help="Question difficulty (default: random weighted)")
    parser.add_argument("--color", default="random",
                        help="Color for beacon/pole (default: random)")
    parser.add_argument("--height", type=int, default=20,
                        help="Height for pole (default: 20)")
    parser.add_argument("--tier", default="random",
                        choices=["random", "small", "medium", "big", "epic"],
                        help="Tier for treasure chest (default: random)")
    parser.add_argument("--length", type=int, default=5,
                        help="Number of puzzles for quiztrail (default: 5)")

    # Database paths
    parser.add_argument("--questionsdb", type=Path, default=DEFAULT_QUESTIONS_DB,
                        help=f"Path to questions database (default: {DEFAULT_QUESTIONS_DB})")
    parser.add_argument("--questionshistory", type=Path, default=DEFAULT_HISTORY_FILE,
                        help=f"Path to history file (default: {DEFAULT_HISTORY_FILE})")

    # AI mode (optional)
    parser.add_argument("--aiendpoint", default=None,
                        help="AI API endpoint for generating questions (optional)")
    parser.add_argument("--apikey", default=None,
                        help="AI API key (required if --aiendpoint is set)")

    # Flags
    parser.add_argument("--dryrun", action="store_true",
                        help="Preview commands without executing")
    parser.add_argument("--reset-history", action="store_true",
                        help="Reset question usage history")
    parser.add_argument("--allow-repeats", action="store_true",
                        help="Allow repeated questions (ignore history)")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Verbose output")
    parser.add_argument("--no-announce", action="store_true",
                        help="Disable achievement announcements")

    args = parser.parse_args()

    # Setup logging
    setup_logging(DEFAULT_LOG_FILE, args.verbose)
    logging.info(f"=== place-treasure.py started - action={args.action} ===")

    # Initialize question database
    question_db = QuestionDatabase(args.questionsdb, args.questionshistory)

    # Reset history if requested
    if args.reset_history:
        question_db.reset_history()
        print("Question history reset")
        if args.action == "puzzlechest":
            pass  # Continue with placement
        else:
            return 0

    # Initialize CLI
    cli = LuantiCLI(args.mtuiurl, args.password)

    # Initialize placer
    placer = TreasurePlacer(cli, question_db)

    # Execute action
    success = False

    if args.action == "puzzlechest":
        # Check for AI mode
        if args.aiendpoint and args.apikey:
            logging.info("Using AI mode for question generation")
            question = generate_ai_question(args.aiendpoint, args.apikey, args.category)
            if question:
                # Use AI-generated question
                tier = DIFFICULTY_TO_TIER.get(question.get("difficulty", "medium"), "medium")
                q_text = question["q"]
                if question.get("hint"):
                    q_text = f"{q_text} (Hint: {question['hint']})"
                command = f"/puzzlechest {tier} {q_text} | {question['a']}"
                success, _ = cli.execute(command, args.dryrun)
            else:
                logging.warning("AI question generation failed, falling back to database")
                success = placer.place_puzzlechest(args.category, args.difficulty, args.dryrun)
        else:
            success = placer.place_puzzlechest(args.category, args.difficulty, args.dryrun)

    elif args.action == "beacon":
        success = placer.place_beacon(args.color, args.dryrun)

    elif args.action == "pole":
        success = placer.place_pole(args.color, args.height, args.dryrun)

    elif args.action == "treasure":
        success = placer.place_treasure(args.tier, args.dryrun)

    elif args.action == "quiztrail":
        success = placer.place_quiztrail(args.length, args.category, args.dryrun)

    if success:
        logging.info("Action completed successfully")
        return 0
    else:
        logging.error("Action failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
