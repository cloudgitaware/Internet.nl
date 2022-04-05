# -*- coding: utf-8 -*-
# Generated by Django 1.11.23 on 2020-06-29 10:06
from __future__ import unicode_literals

import django.db.models.deletion
from django.db import migrations, models

import checks.models


def fix_unused_v4_fields(apps, schema_editor):
    app_name = "checks"
    models = ["NsDomain", "WebDomain", "MxDomain"]
    for current_model in models:
        Model = apps.get_model(app_name, current_model)
        Model.objects.filter(v4_good="").update(v4_good=[])
        Model.objects.filter(v4_bad="").update(v4_bad=[])


class Migration(migrations.Migration):

    dependencies = [
        ("checks", "0003_summer"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="batchcustomview",
            name="users",
        ),
        migrations.AddField(
            model_name="batchrequest",
            name="report_technical_file",
            field=models.FileField(null=True, upload_to="batch_results/"),
        ),
        migrations.AlterField(
            model_name="mxdomain",
            name="mailtestipv6",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="mxdomains",
                to="checks.MailTestIpv6",
            ),
        ),
        migrations.AlterField(
            model_name="mxdomain",
            name="v4_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="mxdomain",
            name="v4_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="mxdomain",
            name="v6_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="mxdomain",
            name="v6_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="domaintestipv6",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="nsdomains",
                to="checks.DomainTestIpv6",
            ),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="mailtestipv6",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="nsdomains",
                to="checks.MailTestIpv6",
            ),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="v4_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="v4_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="v6_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="nsdomain",
            name="v6_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="webdomain",
            name="domaintestipv6",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="webdomains",
                to="checks.DomainTestIpv6",
            ),
        ),
        migrations.AlterField(
            model_name="webdomain",
            name="v4_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="webdomain",
            name="v4_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="webdomain",
            name="v6_bad",
            field=checks.models.ListField(default=[]),
        ),
        migrations.AlterField(
            model_name="webdomain",
            name="v6_good",
            field=checks.models.ListField(default=[]),
        ),
        migrations.DeleteModel(
            name="BatchCustomView",
        ),
        migrations.RunPython(fix_unused_v4_fields, reverse_code=lambda a, b: None),
    ]
