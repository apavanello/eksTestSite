import json


def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "Hello from MiniStack Lambda",
            "path": event.get("path"),
            "method": event.get("httpMethod"),
            "query": event.get("queryStringParameters"),
        }),
    }
