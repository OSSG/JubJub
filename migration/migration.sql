update jubjub_messages set sender_jid = (select jid from jubjub_participants where id = sender), rcpt_jid = (select jid from jubjub_participants where id = rcpt);
