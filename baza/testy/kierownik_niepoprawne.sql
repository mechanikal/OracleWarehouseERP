BEGIN
    DBMS_OUTPUT.PUT_LINE('--- TEST BŁĘDÓW: KIEROWNIK ---');

    BEGIN
        pkg_kierownik.dodaj_kontrahenta('Firma Krzak', '123', 'zly_email.pl');
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('1. Oczekiwany błąd (email): ' || SQLERRM); END;

    DECLARE
        v_id NUMBER;
    BEGIN
        SELECT id_kontrahenta INTO v_id FROM kontrahenci WHERE nazwa_firmy = 'Mleczarnia Centralna';
        pkg_kierownik.usun_kontrahenta(v_id);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('2. Oczekiwany błąd (usuwanie): ' || SQLERRM); END;

    BEGIN
        pkg_kierownik.dodaj_rodzaj_surowca('Zepsute Mleko', -5);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3. Oczekiwany błąd (data): ' || SQLERRM); END;
END;
/
