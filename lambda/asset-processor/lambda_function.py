import json
import boto3
import os

def lambda_handler(event, context):
    """
    Process S3 upload events.
    Logs the filename of uploaded images to CloudWatch.
    """
    print("Lambda function started: bedrock-asset-processor")
    
    # Process each record in the event
    for record in event.get('Records', []):
        if record['eventSource'] == 'aws:s3':
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            event_name = record['eventName']
            
            # Log the uploaded file with event type
            print(f"Image received: {object_key} from bucket: {bucket_name} (Event: {event_name})")
            
            # Check file type
            if object_key.lower().endswith(('.jpg', '.jpeg', '.png', '.gif')):
                print(f"Image file detected: {object_key}")
            else:
                print(f"Non-image file: {object_key}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('File processed successfully!')
    }