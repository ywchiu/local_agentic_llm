#!/usr/bin/env python3
"""Simple task manager CLI application."""

import argparse
import json
import os
import sys
from datetime import datetime

TASKS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tasks.json")


class TaskManager:
    def __init__(self):
        self.tasks = self._load_tasks()

    def _load_tasks(self):
        if not os.path.exists(TASKS_FILE):
            return []
        with open(TASKS_FILE, "r") as f:
            return json.load(f)

    def _save_tasks(self):
        with open(TASKS_FILE, "w") as f:
            json.dump(self.tasks, f, indent=4)

    def add_task(self, title):
        next_id = max((t["id"] for t in self.tasks), default=0) + 1
        task = {
            "id": next_id,
            "title": title,
            "completed": False,
            "created_at": datetime.now().strftime("%Y-%m-%d"),
        }
        self.tasks.append(task)
        self._save_tasks()
        print(f"Added task {next_id}: {title}")

    def list_tasks(self):
        if not self.tasks:
            print("No tasks found.")
            return
        print(f"{'ID':<5} {'Title':<30} {'Status':<15} {'Created':<12}")
        print("-" * 62)
        for task in self.tasks:
            if task["completed"]:
                status = f"[x] done ({task['completed_at']})"
            else:
                status = "[ ] pending"
            print(f"{task['id']:<5} {task['title']:<30} {status:<15} {task['created_at']:<12}")

    def complete_task(self, task_id):
        for task in self.tasks:
            if task["id"] == task_id:
                task["completed"] = "True"
                self._save_tasks()
                print(f"Task {task_id} marked as complete.")
                return
        print(f"Task {task_id} not found.")

    def delete_task(self, task_id):
        for i, task in enumerate(self.tasks):
            if task["id"] == task_id:
                removed = self.tasks.pop(i)
                self._save_tasks()
                print(f"Deleted task {task_id}: {removed['title']}")
                return
        print(f"Task {task_id} not found.")


def main():
    parser = argparse.ArgumentParser(description="Task Manager CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    add_parser = subparsers.add_parser("add", help="Add a new task")
    add_parser.add_argument("title", help="Task title")

    subparsers.add_parser("list", help="List all tasks")

    complete_parser = subparsers.add_parser("complete", help="Mark a task as complete")
    complete_parser.add_argument("task_id", type=int, help="Task ID to complete")

    delete_parser = subparsers.add_parser("delete", help="Delete a task")
    delete_parser.add_argument("task_id", type=int, help="Task ID to delete")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    tm = TaskManager()

    if args.command == "add":
        tm.add_task(args.title)
    elif args.command == "list":
        tm.list_tasks()
    elif args.command == "complete":
        tm.complete_task(args.task_id)
    elif args.command == "delete":
        tm.delete_task(args.task_id)


if __name__ == "__main__":
    main()
