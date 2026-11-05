# tools/concurrency_test

Odpala N równoległych wywołań `transfer_patient` z tą samą `expected_version`. Oczekiwany wynik: dokładnie 1 sukces, N−1 × PT409, +1 wiersz w `location_history`. PLAN §12.1, test akceptacyjny 8.

Status: szkielet, implementacja w osobnym issue.
