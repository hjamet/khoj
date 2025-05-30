# Generated by Django 5.0.9 on 2024-12-09 04:21

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("database", "0076_rename_openaiprocessorconversationconfig_aimodelapi_and_more"),
    ]

    operations = [
        migrations.RenameModel(
            old_name="ChatModelOptions",
            new_name="ChatModel",
        ),
        migrations.RenameField(
            model_name="chatmodel",
            old_name="chat_model",
            new_name="name",
        ),
        migrations.AlterField(
            model_name="agent",
            name="chat_model",
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to="database.chatmodel"),
        ),
        migrations.AlterField(
            model_name="serverchatsettings",
            name="chat_advanced",
            field=models.ForeignKey(
                blank=True,
                default=None,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="chat_advanced",
                to="database.chatmodel",
            ),
        ),
        migrations.AlterField(
            model_name="serverchatsettings",
            name="chat_default",
            field=models.ForeignKey(
                blank=True,
                default=None,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="chat_default",
                to="database.chatmodel",
            ),
        ),
        migrations.AlterField(
            model_name="userconversationconfig",
            name="setting",
            field=models.ForeignKey(
                blank=True,
                default=None,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                to="database.chatmodel",
            ),
        ),
    ]
