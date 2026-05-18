DECLARE
    v_id_kontraktu_wej NUMBER;
    v_id_kontraktu_wyj NUMBER;
    v_id_ser NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PRACOWNIK DOSTAW: OPERACJE ===');
    
    SELECT id_kontraktu INTO v_id_kontraktu_wej FROM kontrakty WHERE czy_wychodzacy = 0 AND ROWNUM = 1;
    SELECT id_kontraktu INTO v_id_kontraktu_wyj FROM kontrakty WHERE czy_wychodzacy = 1 AND ROWNUM = 1;
    SELECT id_rodzaju INTO v_id_ser FROM rodzaje_produktow WHERE nazwa_rodzaju = 'Ser Gouda';

    pkg_pracownik_dostaw.rejestruj_dostawe(v_id_kontraktu_wej, 500000);

    pkg_pracownik_dostaw.wyswietl_statystyki_produkcji;

    pkg_pracownik_dostaw.rejestruj_produkcje(v_id_ser, 20);

    pkg_pracownik_dostaw.wyswietl_stan_magazynu;
    pkg_pracownik_dostaw.wyswietl_statystyki_kontraktow;

    pkg_pracownik_dostaw.rejestruj_dostawe(v_id_kontraktu_wyj, 10);

    DBMS_OUTPUT.PUT_LINE('=== KONIEC DZIAŁAŃ PRACOWNIKA ===');
END;
/
