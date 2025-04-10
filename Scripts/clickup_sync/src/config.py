import os
from typing import Dict, Any
from dotenv import load_dotenv
import logging

logger = logging.getLogger(__name__)

class Config:
    """Configuration handler for ClickUp sync tool."""
    
    REQUIRED_ENV_VARS = [
        'CLICKUP_API_TOKEN',
        'CLICKUP_WORKSPACE_ID',
        'CLICKUP_SPACE_ID',
        'CLICKUP_LIST_ID'
    ]

    def __init__(self):
        """Initialize configuration by loading environment variables."""
        load_dotenv()
        
        # Load configuration from environment
        self.clickup_api_token = os.getenv('CLICKUP_API_TOKEN')
        self.clickup_workspace_id = os.getenv('CLICKUP_WORKSPACE_ID')
        self.clickup_space_id = os.getenv('CLICKUP_SPACE_ID')
        self.clickup_list_id = os.getenv('CLICKUP_LIST_ID')

    def validate(self) -> None:
        """
        Validate that all required configuration variables are set.
        
        Raises:
            ValueError: If any required configuration variable is missing or empty.
        """
        missing_vars = []
        for var in self.REQUIRED_ENV_VARS:
            if not getattr(self, var.lower(), None):
                missing_vars.append(var)
        
        if missing_vars:
            error_msg = f"Missing required environment variables: {', '.join(missing_vars)}"
            logger.error(error_msg)
            raise ValueError(error_msg)

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert configuration to dictionary format.
        
        Returns:
            Dict[str, Any]: Dictionary containing configuration values.
        """
        return {
            'clickup_api_token': self.clickup_api_token,
            'clickup_workspace_id': self.clickup_workspace_id,
            'clickup_space_id': self.clickup_space_id,
            'clickup_list_id': self.clickup_list_id
        }

    @classmethod
    def get_required_vars(cls) -> list:
        """
        Get list of required environment variables.
        
        Returns:
            list: List of required environment variable names.
        """
        return cls.REQUIRED_ENV_VARS
