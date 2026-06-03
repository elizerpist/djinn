import pytest

import app.main as main


@pytest.fixture(autouse=True)
def reset_backend_state():
    main.documents._documents.clear()
    main.chunks.clear()
    main.store._messages.clear()
    main.store._created_at.clear()
    main.store._updated_at.clear()
    main.store._titles.clear()
    yield
