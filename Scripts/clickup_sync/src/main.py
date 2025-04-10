from config import Config
from clickup_client import ClickUpClient
from task_analyzer import TaskAnalyzer
import sys
import logging
import json
import argparse
from typing import Dict, Any

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def preview_tasks(tasks: Dict[str, Any], indent: int = 0) -> None:
    """
    Displays a hierarchical preview of the tasks that will be created.
    """
    for task in tasks:
        print("  " * indent + f"• {task['name']}")
        print("  " * (indent + 1) + f"Description: {task['description']}")
        if 'subtasks' in task and task['subtasks']:
            for subtask in task['subtasks']:
                print("  " * (indent + 1) + f"  ◦ {subtask['name']}")
                print("  " * (indent + 2) + f"Description: {subtask['description']}")
                if 'subtasks' in subtask and subtask['subtasks']:
                    for nested_subtask in subtask['subtasks']:
                        print("  " * (indent + 2) + f"    ▪ {nested_subtask['name']}")
                        print("  " * (indent + 3) + f"Description: {nested_subtask['description']}")

def main():
    parser = argparse.ArgumentParser(description='Sync project tasks to ClickUp')
    parser.add_argument('--preview', action='store_true', help='Preview tasks without creating them')
    parser.add_argument('--save', action='store_true', help='Save task structure to JSON file')
    parser.add_argument('--load', type=str, help='Load task structure from JSON file')
    args = parser.parse_args()

    try:
        # Initialize task analyzer
        analyzer = TaskAnalyzer()

        # Load tasks from file if specified
        if args.load:
            logger.info(f"Loading task structure from {args.load}")
            tasks = analyzer.load_task_structure(args.load)
        else:
            # Analyze project and get task structure
            logger.info("Analyzing project structure...")
            tasks = analyzer.analyze_project(".")

        # Save task structure if requested
        if args.save:
            filename = "task_structure.json"
            logger.info(f"Saving task structure to {filename}")
            analyzer.save_task_structure(filename)

        # Preview tasks if requested
        if args.preview:
            print("\nTask Structure Preview:")
            print("=====================\n")
            preview_tasks(tasks)
            print("\nTo create these tasks in ClickUp, run the script without --preview")
            sys.exit(0)

        # Load and validate configuration
        config = Config()
        config.validate()

        # Initialize ClickUp client
        client = ClickUpClient(config.clickup_api_token)

        # Create tasks in ClickUp
        logger.info("Creating tasks in ClickUp...")
        for task in tasks:
            try:
                created_task = client.create_task_hierarchy(
                    config.clickup_list_id,
                    task
                )
                logger.info(f"Successfully created task hierarchy for: {task['name']}")
            except Exception as e:
                logger.error(f"Failed to create task hierarchy for {task['name']}: {str(e)}")
                continue

        logger.info("Task synchronization completed successfully!")

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
