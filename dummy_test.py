import json

dummy = {
    "providers": [
        {
            "Name": "s3",
            "Description": "Amazon S3 Compliant Storage Providers",
            "Prefix": "s3",
            "Options": []
        }
    ]
}

print(json.dumps(dummy))
