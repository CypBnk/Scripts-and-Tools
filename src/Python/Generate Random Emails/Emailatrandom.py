import random
from datetime import datetime
from pathlib import Path
import win32com.client  # Required for creating MSG files

# Function to generate random email content
def generate_random_email_content():
    subjects = [
        "Meeting Reminder", "Invoice Details", "Welcome to Our Service",
        "Your Subscription Update", "Special Offer Just for You",
        "Project Update", "Weekly Newsletter", "Important Announcement",
        "Event Invitation", "Feedback Request"
    ]
    bodies = [
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
    
    subject = random.choice(subjects)
    body = random.choice(bodies)
    return subject, body

# Function to create MSG files
def create_msg_file(subject, body, output_dir):
    outlook = win32com.client.Dispatch("Outlook.Application")
    msg = outlook.CreateItem(0)  # Create a new mail item
    msg.Subject = subject
    msg.Body = body
    # Save as MSG file
    filename = f"{subject[:30].replace(' ', '_')}_{datetime.now().strftime('%Y%m%d%H%M%S')}.msg"
    msg.SaveAs(str(output_dir / filename))

# Generate a random number of emails between 30 and 150
num_emails = random.randint(30, 150)
output_dir = Path("Generated_Emails")
output_dir.mkdir(exist_ok=True)

for _ in range(num_emails):
    subject, body = generate_random_email_content()
    create_msg_file(subject, body, output_dir)

print(f"Generated {num_emails} MSG files in '{output_dir}' directory.")
