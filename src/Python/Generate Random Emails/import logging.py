import logging
import random
import time
from datetime import datetime
from pathlib import Path
import win32com.client
from win32com.client import constants
import pythoncom

def generate_random_email_content():
    subjects = [  # Added subjects list
        "Meeting Reminder", "Invoice Details", "Welcome to Our Service",
        "Your Subscription Update", "Special Offer Just for You",
        "Project Update", "Weekly Newsletter", "Important Announcement",
        "Event Invitation", "Feedback Request"
    ]
    bodies = [  # Added bodies list
        "Dear user,\n\nThank you for choosing our service. We hope you enjoy your experience.",
        "Hello,\n\nPlease find attached the invoice for your recent purchase.",
        "Hi there,\n\nWe are excited to have you on board. Let us know if you need any assistance.",
        "Dear customer,\n\nYour subscription has been successfully updated. Thank you for staying with us.",
        "Hello,\n\nDon't miss out on our exclusive offer. Visit our website for more details.",
        "Dear team,\n\nHere is the latest update on the project. Please review and provide feedback.",
        "Hi,\n\nCheck out this week's newsletter for exciting news and updates!",
        "Attention:\n\nWe have an important announcement to share with you. Please read carefully.",
        "You're invited!\n\nJoin us at our upcoming event. Details are attached.",
        "Hello,\n\nWe value your opinion! Please take a moment to provide your feedback."
    ]
    return random.choice(subjects), random.choice(bodies)

# Configure logging
logging.basicConfig(filename="error_log.txt", level=logging.ERROR, format="%(asctime)s - %(message)s")

def create_msg_file(subject, body, output_dir):
    try:
        # Initialize Outlook COM object
        outlook = win32com.client.Dispatch("Outlook.Application")
        msg = outlook.CreateItem(0)

        # Configure email
        msg.Subject = subject[:255]  # Truncate subject to avoid long filenames
        msg.Body = body
        # NOTE: Replace with your actual recipient email address
        msg.To = "recipient@yourdomain.com"

        # Create safe filename
        clean_subject = "".join(c if c.isalnum() else "_" for c in subject)
        filename = f"{clean_subject[:30]}_{datetime.now().strftime('%Y%m%d%H%M%S')}.msg"
        full_path = output_dir / filename

        # Save email as MSG file
        msg.SaveAs(str(full_path), constants.olMSG)
        return True

    except Exception as e:
        logging.error(f"Failed to save email '{subject}' to {output_dir}. Error: {e}")
        return False
# Configuration
#output_dir = Path.cwd() / "Generated_Emails"
output_dir = "c:/develop/python/Generated_Emails"
#output_dir.mkdir(parents=True, exist_ok=True)

# Generate emails
success_count = 0
num_emails = random.randint(30, 150)

for _ in range(num_emails):
    subject, body = generate_random_email_content()
    if create_msg_file(subject, body, output_dir):
        success_count += 1
    time.sleep(0.1)  # Add delay between creations

print(f"Created {success_count} emails in {output_dir}")
