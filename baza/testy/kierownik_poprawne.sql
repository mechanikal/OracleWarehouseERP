SET SERVEROUTPUT ON;
DECLARE
    v_id_mleko NUMBER;
    v_id_ser   NUMBER;
    v_id_dost  NUMBER;
    v_id_klient NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== KIEROWNIK: KONFIGURACJA SYSTEMU ===');

    pkg_kierownik.dodaj_rodzaj_surowca('Świeże Mleko', 3, 60, 3.2, 4.7, 3.8);
    pkg_kierownik.dodaj_rodzaj_produktu('Ser Gouda', 20, 15.50);
    
    SELECT id_rodzaju INTO v_id_mleko FROM rodzaje_surowcow WHERE nazwa_surowca = 'Świeże Mleko' AND ROWNUM=1;
    SELECT id_rodzaju INTO v_id_ser FROM rodzaje_produktow WHERE nazwa_rodzaju = 'Ser Gouda' AND ROWNUM=1;

    pkg_kierownik.receptura_dodaj_skladnik(v_id_ser, v_id_mleko, 10000);

    pkg_kierownik.dodaj_kontrahenta('Mleczarnia Centralna', '111-222-333', 'biuro@mleczarnia.pl');
    pkg_kierownik.dodaj_kontrahenta('Sieć Sklepów Biedronka', '999-888-777', 'zakupy@biedronka.pl');

    SELECT id_kontrahenta INTO v_id_dost FROM kontrahenci WHERE nazwa_firmy = 'Mleczarnia Centralna';
    SELECT id_kontrahenta INTO v_id_klient FROM kontrahenci WHERE nazwa_firmy = 'Sieć Sklepów Biedronka';

    pkg_kierownik.dodaj_kontrakt(v_id_dost, 'WEJ', v_id_mleko, 500000, 0.20, 'TYGODNIOWY', 1, SYSDATE+180);
    
    pkg_kierownik.dodaj_zamowienie_jednorazowe(v_id_klient, 'WYJ', v_id_ser, 10, 25.00);

    pkg_kierownik.wyswietl_rodzaje_surowcow;
    pkg_kierownik.wyswietl_rodzaje_produktow;
    pkg_kierownik.wyswietl_kontrahentow;
    pkg_kierownik.wyswietl_kontrakty;
    
    DBMS_OUTPUT.PUT_LINE('=== KONIEC DZIAŁAŃ KIEROWNIKA ===');
END;
/
