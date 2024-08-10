import boto3
import os
from time import time

client = boto3.client('codepipeline')
cf_client = boto3.client('cloudfront')

def lambda_handler(event, context):
  try:
    cf_client.create_invalidation(
      DistributionId=os.environ['DISTRIBUTION_ID'],
      InvalidationBatch={
        'Paths': {
          'Quantity': 1,
          'Items': [
            '/*',
          ]
        },
        'CallerReference': str(time())
      }
    )

    client.put_job_success_result(
      jobId=event['CodePipeline.job']['id']
    )
  except Exception as err:
    client.put_job_failure_result(
      jobId=event['CodePipeline.job']['id'],
      failureDetails={
        'message': str(err),
        'type': 'JobFailed'
      }
    )
    raise
