import requests
import time
import random
from typing import Dict, Any, List, Optional, Union
import logging
from requests.exceptions import RequestException, HTTPError, Timeout, ConnectionError

logger = logging.getLogger(__name__)

class ClickUpAPIError(Exception):
    """Custom exception for ClickUp API errors."""
    def __init__(self, message: str, status_code: Optional[int] = None, response: Optional[Dict[str, Any]] = None):
        self.status_code = status_code
        self.response = response
        super().__init__(message)


class ClickUpClient:
    BASE_URL = "https://api.clickup.com/api/v2"
    
    def __init__(self, api_token: str, max_retries: int = 3, retry_delay: float = 1.0):
        """
        Initialize the ClickUp client.
        
        Args:
            api_token: The ClickUp API token.
            max_retries: Maximum number of retry attempts for failed requests.
            retry_delay: Base delay in seconds between retries.
        """
        self.headers = {
            "Authorization": api_token,
            "Content-Type": "application/json"
        }
        self.max_retries = max_retries
        self.retry_delay = retry_delay

    def create_task_hierarchy(self, list_id: str, task_structure: Dict[str, Any]) -> Dict[str, Any]:
        """
        Creates a full task hierarchy in ClickUp based on the provided structure.
        Handles main tasks and their subtasks recursively.
        """
        try:
            # Create the main task
            main_task = self.create_task(
                list_id=list_id,
                name=task_structure["name"],
                description=task_structure["description"]
            )
            
            logger.info(f"Created main task: {task_structure['name']}")

            # If there are subtasks, create them and link to the main task
            if "subtasks" in task_structure and task_structure["subtasks"]:
                for subtask_data in task_structure["subtasks"]:
                    try:
                        subtask = self.create_subtask(
                            parent_id=main_task["id"],
                            name=subtask_data["name"],
                            description=subtask_data["description"]
                        )
                        logger.info(f"Created subtask: {subtask_data['name']}")

                        # Handle nested subtasks if they exist
                        if "subtasks" in subtask_data and subtask_data["subtasks"]:
                            for nested_subtask_data in subtask_data["subtasks"]:
                                try:
                                    nested_subtask = self.create_subtask(
                                        parent_id=subtask["id"],
                                        name=nested_subtask_data["name"],
                                        description=nested_subtask_data["description"]
                                    )
                                    logger.info(f"Created nested subtask: {nested_subtask_data['name']}")
                                except Exception as e:
                                    logger.error(f"Failed to create nested subtask {nested_subtask_data['name']}: {str(e)}")

                    except Exception as e:
                        logger.error(f"Failed to create subtask {subtask_data['name']}: {str(e)}")

            return main_task

        except Exception as e:
            logger.error(f"Failed to create task hierarchy for {task_structure['name']}: {str(e)}")
            raise

    def _make_request(self, method: str, endpoint: str, json_data: Optional[Dict[str, Any]] = None, 
                    params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Make a request to the ClickUp API with retry logic and exponential backoff.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE).
            endpoint: API endpoint to call (without base URL).
            json_data: JSON payload for POST/PUT requests.
            params: Query parameters for the request.
            
        Returns:
            Dict containing the API response.
            
        Raises:
            ClickUpAPIError: When the API request fails after all retries.
        """
        url = f"{self.BASE_URL}{endpoint}"
        retry_count = 0
        
        while retry_count <= self.max_retries:
            try:
                response = requests.request(
                    method=method,
                    url=url,
                    headers=self.headers,
                    json=json_data,
                    params=params
                )
                
                # Check for rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get('Retry-After', 60))
                    logger.warning(f"Rate limited. Waiting for {retry_after} seconds before retrying.")
                    time.sleep(retry_after)
                    retry_count += 1
                    continue
                
                # Raise for other HTTP errors
                response.raise_for_status()
                
                return response.json()
                
            except (ConnectionError, Timeout) as e:
                retry_count += 1
                if retry_count > self.max_retries:
                    logger.error(f"Max retries exceeded for {url}: {str(e)}")
                    raise ClickUpAPIError(f"Connection error after {self.max_retries} retries: {str(e)}")
                
                # Exponential backoff with jitter
                sleep_time = self.retry_delay * (2 ** (retry_count - 1)) + random.uniform(0, 1)
                logger.warning(f"Connection error. Retrying in {sleep_time:.2f} seconds. Attempt {retry_count}/{self.max_retries}")
                time.sleep(sleep_time)
                
            except HTTPError as e:
                # Get response data for error context
                error_detail = ""
                try:
                    error_data = response.json()
                    error_detail = f": {error_data.get('err', '')}"
                except:
                    pass
                
                error_message = f"HTTP Error {response.status_code}{error_detail} for {url}"
                logger.error(error_message)
                
                # For server errors (5xx), retry with backoff
                if 500 <= response.status_code < 600:
                    retry_count += 1
                    if retry_count > self.max_retries:
                        raise ClickUpAPIError(error_message, response.status_code, error_data if 'error_data' in locals() else None)
                    
                    sleep_time = self.retry_delay * (2 ** (retry_count - 1)) + random.uniform(0, 1)
                    logger.warning(f"Server error. Retrying in {sleep_time:.2f} seconds. Attempt {retry_count}/{self.max_retries}")
                    time.sleep(sleep_time)
                else:
                    # For client errors (4xx), don't retry (except for 429 which is handled above)
                    raise ClickUpAPIError(error_message, response.status_code, error_data if 'error_data' in locals() else None)
            
            except Exception as e:
                logger.error(f"Unexpected error for {url}: {str(e)}")
                raise ClickUpAPIError(f"Unexpected error: {str(e)}")
        
        # If we've exhausted all retries
        raise ClickUpAPIError(f"Request failed after {self.max_retries} retries")

    def create_task(self, list_id: str, name: str, description: str, 
                    subtasks: List[Dict[str, str]] = None, custom_fields: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        """
        Creates a new task in the specified list.
        
        Args:
            list_id: The ID of the list to create the task in.
            name: The name of the task.
            description: The description of the task.
            subtasks: Optional list of subtasks to create.
            custom_fields: Optional list of custom fields to set on the task.
            
        Returns:
            Dict containing the created task data.
        """
        endpoint = f"/list/{list_id}/task"
        
        payload = {
            "name": name,
            "description": description,
            "status": "to do",
            "priority": 3,  # Normal priority
            "markdown_description": True
        }
        
        # Add custom fields if provided
        if custom_fields:
            payload["custom_fields"] = custom_fields
            
        task_data = self._make_request("POST", endpoint, json_data=payload)
        # Create subtasks if provided
        if subtasks and task_data.get('id'):
            for subtask in subtasks:
                self.create_subtask(
                    task_data['id'], 
                    subtask['name'], 
                    subtask.get('description', ''),
                    custom_fields=subtask.get('custom_fields')
                )

        return task_data

    def create_subtask(self, parent_id: str, name: str, description: str, 
                       custom_fields: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        """
        Creates a subtask under the specified parent task.
        
        Args:
            parent_id: The ID of the parent task.
            name: The name of the subtask.
            description: The description of the subtask.
            custom_fields: Optional list of custom fields to set on the subtask.
            
        Returns:
            Dict containing the created subtask data.
        """
        endpoint = f"/task/{parent_id}/subtask"
        
        payload = {
            "name": name,
            "description": description,
            "status": "to do",
            "priority": 3,  # Normal priority
            "markdown_description": True
        }
        
        # Add custom fields if provided
        if custom_fields:
            payload["custom_fields"] = custom_fields
            
        return self._make_request("POST", endpoint, json_data=payload)

    def get_task(self, task_id: str) -> Dict[str, Any]:
        """
        Retrieves a task by its ID.
        
        Args:
            task_id: The ID of the task to retrieve.
            
        Returns:
            Dict containing the task data.
        """
        endpoint = f"/task/{task_id}"
        return self._make_request("GET", endpoint)

    def update_task_status(self, task_id: str, status: str) -> Dict[str, Any]:
        """
        Updates the status of a task.
        
        Args:
            task_id: The ID of the task to update.
            status: The new status of the task.
            
        Returns:
            Dict containing the updated task data.
        """
        endpoint = f"/task/{task_id}"
        payload = {
            "status": status
        }
        return self._make_request("PUT", endpoint, json_data=payload)
        
    def get_tasks(self, list_id: str, archived: bool = False, page: int = 0, 
                 order_by: str = "created", reverse: bool = True, 
                 subtasks: bool = True, statuses: Optional[List[str]] = None,
                 include_closed: bool = False, assignees: Optional[List[str]] = None,
                 due_date_gt: Optional[int] = None, due_date_lt: Optional[int] = None) -> Dict[str, Any]:
        """
        Retrieves tasks from a list with various filtering options.
        
        Args:
            list_id: The ID of the list to retrieve tasks from.
            archived: Whether to include archived tasks.
            page: The page number for pagination.
            order_by: Field to order results by (created, updated, due_date).
            reverse: Whether to reverse the order.
            subtasks: Whether to include subtasks.
            statuses: Optional list of statuses to filter by.
            include_closed: Whether to include closed tasks.
            assignees: Optional list of assignee user IDs to filter by.
            due_date_gt: Optional filter for tasks due after this timestamp.
            due_date_lt: Optional filter for tasks due before this timestamp.
            
        Returns:
            Dict containing the tasks data.
        """
        endpoint = f"/list/{list_id}/task"
        
        params = {
            "archived": str(archived).lower(),
            "page": page,
            "order_by": order_by,
            "reverse": str(reverse).lower(),
            "subtasks": str(subtasks).lower(),
            "include_closed": str(include_closed).lower()
        }
        
        if statuses:
            params["statuses[]"] = statuses
            
        if assignees:
            params["assignees[]"] = assignees
            
        if due_date_gt:
            params["due_date_gt"] = due_date_gt
            
        if due_date_lt:
            params["due_date_lt"] = due_date_lt
            
        return self._make_request("GET", endpoint, params=params)
    
    def get_custom_fields(self, list_id: str) -> Dict[str, Any]:
        """
        Retrieves custom fields for a list.
        
        Args:
            list_id: The ID of the list to retrieve custom fields from.
            
        Returns:
            Dict containing the custom fields data.
        """
        endpoint = f"/list/{list_id}/field"
        return self._make_request("GET", endpoint)

    # Webhook Management Methods
    
    def create_webhook(self, workspace_id: str, endpoint: str, 
                       events: List[str] = None, status: str = "active") -> Dict[str, Any]:
        """
        Creates a new webhook for a workspace.
        
        Args:
            workspace_id: The ID of the workspace.
            endpoint: The URL endpoint that will receive webhook events.
            events: List of event types to subscribe to. If None, defaults to basic task events.
            status: Webhook status, either 'active' or 'inactive'.
            
        Returns:
            Dict containing the created webhook data.
        """
        endpoint_url = f"/team/{workspace_id}/webhook"
        
        # Default events if none provided
        if events is None:
            events = ["taskCreated", "taskUpdated", "taskDeleted", "taskStatusUpdated"]
            
        payload = {
            "endpoint": endpoint,
            "events": events,
            "status": status
        }
        
        return self._make_request("POST", endpoint_url, json_data=payload)
    
    def delete_webhook(self, webhook_id: str) -> Dict[str, Any]:
        """
        Deletes an existing webhook.
        
        Args:
            webhook_id: The ID of the webhook to delete.
            
        Returns:
            Dict containing the response data.
        """
        endpoint = f"/webhook/{webhook_id}"
        return self._make_request("DELETE", endpoint)
    
    def get_webhooks(self, workspace_id: str) -> Dict[str, Any]:
        """
        Retrieves all webhooks for a workspace.
        
        Args:
            workspace_id: The ID of the workspace.
            
        Returns:
            Dict containing the webhooks data.
        """
        endpoint = f"/team/{workspace_id}/webhook"
        return self._make_request("GET", endpoint)
    
    def update_webhook_status(self, webhook_id: str, status: str) -> Dict[str, Any]:
        """
        Updates the status of a webhook.
        
        Args:
            webhook_id: The ID of the webhook to update.
            status: The new status, either 'active' or 'inactive'.
            
        Returns:
            Dict containing the updated webhook data.
        """
        endpoint = f"/webhook/{webhook_id}"
        payload = {
            "status": status
        }
        return self._make_request("PUT", endpoint, json_data=payload)
    
    # Custom Field Management Methods
    
    def update_custom_field_value(self, task_id: str, field_id: str, value: Any) -> Dict[str, Any]:
        """
        Updates a specific custom field value for a task.
        
        Args:
            task_id: The ID of the task.
            field_id: The ID of the custom field.
            value: The new value for the custom field.
            
        Returns:
            Dict containing the response data.
        """
        endpoint = f"/task/{task_id}/field/{field_id}"
        payload = {
            "value": value
        }
        return self._make_request("POST", endpoint, json_data=payload)
    
    def bulk_update_custom_fields(self, task_id: str, 
                                 custom_fields: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Updates multiple custom fields for a task in a single request.
        
        Args:
            task_id: The ID of the task.
            custom_fields: List of custom field objects with field_id and value.
                Each item should be a dict with 'id' and 'value' keys.
            
        Returns:
            Dict containing the response data.
        """
        endpoint = f"/task/{task_id}"
        payload = {
            "custom_fields": custom_fields
        }
        return self._make_request("PUT", endpoint, json_data=payload)
    
    def set_custom_field_value(self, task_id: str, field_name: str, 
                              value: Any) -> Dict[str, Any]:
        """
        Sets a custom field value by field name.
        This is a convenience method that first looks up the field ID by name.
        
        Args:
            task_id: The ID of the task.
            field_name: The name of the custom field.
            value: The new value for the custom field.
            
        Returns:
            Dict containing the response data.
            
        Raises:
            ClickUpAPIError: If the custom field with the given name is not found.
        """
        # First get task to find the list_id
        task_data = self.get_task(task_id)
        list_id = task_data.get("list", {}).get("id")
        
        if not list_id:
            raise ClickUpAPIError(f"Could not determine list ID for task {task_id}")
        
        # Get custom fields for the list
        fields_data = self.get_custom_fields(list_id)
        fields = fields_data.get("fields", [])
        
        # Find the field with matching name
        field_id = None
        for field in fields:
            if field.get("name") == field_name:
                field_id = field.get("id")
                break
        
        if not field_id:
            raise ClickUpAPIError(f"Custom field '{field_name}' not found for task {task_id}")
        
        # Update the field value
        return self.update_custom_field_value(task_id, field_id, value)
    
    def get_task_custom_fields(self, task_id: str) -> Dict[str, Any]:
        """
        Retrieves all custom fields for a task.
        
        Args:
            task_id: The ID of the task.
            
        Returns:
            Dict containing the custom fields data.
        """
        # Get the task which includes custom fields
        task_data = self.get_task(task_id)
        
        # Extract and return just the custom fields
        custom_fields = task_data.get("custom_fields", [])
        return {"custom_fields": custom_fields}
