DECLARE
    v_id_ser NUMBER;
    v_id_kontraktu NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- TEST BŁĘDÓW: PRACOWNIK DOSTAW ---');
    
    SELECT id_rodzaju INTO v_id_ser FROM rodzaje_produktow WHERE nazwa_rodzaju = 'Ser Gouda';
    SELECT id_kontraktu INTO v_id_kontraktu FROM kontrakty WHERE czy_wychodzacy = 1 AND ROWNUM=1;

    BEGIN
        pkg_pracownik_dostaw.rejestruj_produkcje(v_id_ser, 1000000);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('1. Oczekiwany błąd (brak surowca): ' || SQLERRM); END;

    BEGIN
        pkg_pracownik_dostaw.rejestruj_dostawe(-999, 100);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('2. Oczekiwany błąd (zły kontrakt): ' || SQLERRM); END;
    
    BEGIN
        pkg_pracownik_dostaw.rejestruj_dostawe(v_id_kontraktu, 500);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3. Oczekiwany błąd (Przekroczono limit dostaw w cyklu!): ' || SQLERRM); END;
END;
/
