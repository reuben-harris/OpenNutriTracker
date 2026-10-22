"""Source-independent value validation and canonical serialization."""

import hashlib
import json
from decimal import Decimal, InvalidOperation
from pathlib import Path

class ValidationError(ValueError):
    pass


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def decimal_value(value):
    if value is None or value == '':
        return None
    try:
        number = Decimal(str(value))
        if not number.is_finite():
            raise InvalidOperation
        return str(value)
    except InvalidOperation as error:
        raise ValidationError(f'Invalid finite decimal: {value!r}') from error
