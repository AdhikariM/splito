/* eslint-disable */

import {SendEmailCommand, SESClient} from "@aws-sdk/client-ses";
import { config } from 'firebase-functions';

// Fetch AWS credentials securely from Firebase configuration
const AWS_ACCESS_KEY_ID = config().aws.access_key_id;
const AWS_SECRET_ACCESS_KEY = config().aws.secret_access_key;

if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY) {
  throw new Error('AWS credentials are not set in Firebase Functions config');
}

const REGION = "ap-south-1";
const sesClient = new SESClient({
  credentials: {
    accessKeyId: AWS_ACCESS_KEY_ID,
    secretAccessKey: AWS_SECRET_ACCESS_KEY,
  },
  region: REGION,
});

export class MailService {
  private createSendEmailCommand(toAddresses: string[], fromAddress: string, subject: string, body: string): SendEmailCommand {
    return new SendEmailCommand({
      Destination: {
        CcAddresses: [
        ],
        ToAddresses: toAddresses,
      },
      Message: {
        Body: {
          Text: {
            Charset: "UTF-8",
            Data: body,
          },
        },
        Subject: {
          Charset: "UTF-8",
          Data: subject,
        },
      },
      Source: fromAddress,
      ReplyToAddresses: [
      ],
    });
  }

  async sendEmail(to: string[], from: string, subject: string, body: string): Promise<void> {
    const mail = this.createSendEmailCommand(to, from, subject, body);
    await sesClient.send(mail);
  }
}