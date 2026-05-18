CREATE OR REPLACE PACKAGE pkg_kierownik AS
    PROCEDURE dodaj_kontrahenta(
        p_nazwa_firmy    VARCHAR2,
        p_numer_telefonu VARCHAR2,
        p_adres_email    VARCHAR2
    );
    PROCEDURE usun_kontrahenta(p_id_kontrahenta NUMBER);

    PROCEDURE dodaj_kontrakt(
        p_id_kontrahenta NUMBER,
        p_typ_transakcji VARCHAR2,
        p_id_przedmiotu  NUMBER,
        p_ilosc_g        NUMBER,
        p_cena_za_100g   NUMBER,
        p_cykl           VARCHAR2,
        p_ile_w_cyklu    NUMBER,
        p_data_wygas     DATE
    );
    PROCEDURE usun_kontrakt(p_id_kontraktu NUMBER);

    PROCEDURE receptura_dodaj_skladnik(
        p_id_produktu NUMBER,
        p_id_surowca  NUMBER,
        p_ilosc_g     NUMBER
    );
    PROCEDURE receptura_usun_skladnik(
        p_id_produktu NUMBER,
        p_id_surowca  NUMBER
    );

    PROCEDURE dodaj_zamowienie_jednorazowe(
        p_id_kontrahenta NUMBER,
        p_typ_transakcji VARCHAR2,
        p_id_przedmiotu  NUMBER,
        p_ilosc_g        NUMBER,
        p_cena_za_100g   NUMBER
    );

    PROCEDURE dodaj_rodzaj_produktu(
        p_nazwa VARCHAR2, 
        p_dni_zdatnosci NUMBER, 
        p_koszt_produkcji NUMBER
    );
    PROCEDURE usun_rodzaj_produktu(p_id_rodzaju NUMBER);
    PROCEDURE dodaj_rodzaj_surowca(
        p_nazwa VARCHAR2, 
        p_dni_zdatnosci NUMBER, 
        p_kcal NUMBER DEFAULT 0, 
        p_bialko NUMBER DEFAULT 0, 
        p_wegle NUMBER DEFAULT 0, 
        p_tluszcz NUMBER DEFAULT 0
    );
    PROCEDURE usun_rodzaj_surowca(p_id_surowca NUMBER);

    PROCEDURE wyswietl_bilans_zyskow_strat;
    PROCEDURE wyswietl_rodzaje_produktow;
    PROCEDURE wyswietl_rodzaje_surowcow;
    PROCEDURE wyswietl_kontrahentow;
    PROCEDURE wyswietl_kontrakty;
END pkg_kierownik;
/

CREATE OR REPLACE PACKAGE BODY pkg_kierownik AS
    FUNCTION pobierz_ref_kontrahenta(p_id NUMBER) RETURN REF t_kontrahent IS
        v_ref REF t_kontrahent;
    BEGIN
        SELECT REF(k) INTO v_ref FROM kontrahenci k WHERE id_kontrahenta = p_id;
        RETURN v_ref;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20201, 'Nie znaleziono kontrahenta o ID: ' || p_id);
    END;

    PROCEDURE dodaj_kontrahenta(
        p_nazwa_firmy    VARCHAR2,
        p_numer_telefonu VARCHAR2,
        p_adres_email    VARCHAR2
    ) IS
    BEGIN
        INSERT INTO kontrahenci VALUES (
            t_kontrahent(p_nazwa_firmy, p_numer_telefonu, p_adres_email)
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Dodano kontrahenta "' || p_nazwa_firmy || '".');
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Błąd: Kontrahent o podanej nazwie lub e-mailu już istnieje!');
    END dodaj_kontrahenta;

    PROCEDURE usun_kontrahenta(p_id_kontrahenta NUMBER) IS
    BEGIN
        DELETE FROM kontrahenci WHERE id_kontrahenta = p_id_kontrahenta;
        
        IF SQL%ROWCOUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono kontrahenta o ID ' || p_id_kontrahenta);
        ELSE
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Sukces: Usunięto kontrahenta ID ' || p_id_kontrahenta);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -2292 THEN
                DBMS_OUTPUT.PUT_LINE('Błąd: Nie można usunąć kontrahenta, który posiada aktywne kontrakty!');
            ELSE
                RAISE;
            END IF;
    END usun_kontrahenta;

    PROCEDURE dodaj_kontrakt(
        p_id_kontrahenta NUMBER,
        p_typ_transakcji VARCHAR2,
        p_id_przedmiotu  NUMBER,
        p_ilosc_g        NUMBER,
        p_cena_za_100g   NUMBER,
        p_cykl           VARCHAR2,
        p_ile_w_cyklu    NUMBER,
        p_data_wygas     DATE
    ) IS
        v_kontrahent_ref REF t_kontrahent;
    BEGIN
        v_kontrahent_ref := pobierz_ref_kontrahenta(p_id_kontrahenta);
        INSERT INTO kontrakty VALUES (
            t_kontrakt(
                p_kontrahent_ref => v_kontrahent_ref,
                p_id_przedmiotu  => p_id_przedmiotu,
                p_data_sporz     => SYSDATE,
                p_data_wygas     => p_data_wygas,
                p_cykl           => p_cykl,
                p_ile_w_cyklu    => p_ile_w_cyklu,
                p_cena           => p_cena_za_100g,
                p_ilosc          => p_ilosc_g,
                p_czy_wychodzacy => p_typ_transakcji
            )
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Dodano nowy kontrakt.');
    END dodaj_kontrakt;

    PROCEDURE usun_kontrakt(p_id_kontraktu NUMBER) IS
    BEGIN
        DELETE FROM kontrakty WHERE id_kontraktu = p_id_kontraktu;
        
        IF SQL%ROWCOUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono kontraktu o ID ' || p_id_kontraktu);
        ELSE
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Sukces: Usunięto kontrakt ID ' || p_id_kontraktu);
        END IF;
    END usun_kontrakt;

    PROCEDURE receptura_dodaj_skladnik(
        p_id_produktu NUMBER,
        p_id_surowca  NUMBER,
        p_ilosc_g     NUMBER
    ) IS
        v_prod t_rodzaj_produktu;
    BEGIN
        SELECT VALUE(r) INTO v_prod 
        FROM rodzaje_produktow r 
        WHERE id_rodzaju = p_id_produktu 
        FOR UPDATE;

        v_prod.dodaj_skladnik(p_id_surowca, p_ilosc_g);

        UPDATE rodzaje_produktow r 
        SET VALUE(r) = v_prod 
        WHERE id_rodzaju = p_id_produktu;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Zaktualizowano recepturę produktu ID ' || p_id_produktu || '.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono produktu o ID: ' || p_id_produktu);
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -20005 THEN
                DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono surowca o ID: ' || p_id_surowca);
            ELSE
                DBMS_OUTPUT.PUT_LINE('Błąd edycji receptury: ' || SQLERRM);
            END IF;
    END receptura_dodaj_skladnik;

    PROCEDURE receptura_usun_skladnik(
        p_id_produktu NUMBER,
        p_id_surowca  NUMBER
    ) IS
        v_prod t_rodzaj_produktu;
    BEGIN
        SELECT VALUE(r) INTO v_prod
        FROM rodzaje_produktow r
        WHERE id_rodzaju = p_id_produktu
        FOR UPDATE;

        v_prod.usun_skladnik(p_id_surowca);

        UPDATE rodzaje_produktow r
        SET VALUE(r) = v_prod
        WHERE id_rodzaju = p_id_produktu;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Usunięto składnik ID ' || p_id_surowca || ' z produktu ID ' || p_id_produktu || '.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono produktu o ID: ' || p_id_produktu);
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Błąd usuwania składnika: ' || SQLERRM);
    END receptura_usun_skladnik;

    PROCEDURE dodaj_zamowienie_jednorazowe(
        p_id_kontrahenta NUMBER,
        p_typ_transakcji VARCHAR2,
        p_id_przedmiotu  NUMBER,
        p_ilosc_g        NUMBER,
        p_cena_za_100g   NUMBER
    ) IS
        v_kontrahent_ref REF t_kontrahent;
    BEGIN
        v_kontrahent_ref := pobierz_ref_kontrahenta(p_id_kontrahenta);

        INSERT INTO kontrakty VALUES (
            t_kontrakt(
                p_kontrahent_ref => v_kontrahent_ref,
                p_id_przedmiotu  => p_id_przedmiotu,
                p_data_sporz     => SYSDATE,
                p_data_wygas     => SYSDATE + 7,
                p_cykl           => 'JEDNORAZOWY',
                p_ile_w_cyklu    => 1,
                p_cena           => p_cena_za_100g,
                p_ilosc          => p_ilosc_g,
                p_czy_wychodzacy => p_typ_transakcji
            )
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Dodano zamówienie jednorazowe.');
    END dodaj_zamowienie_jednorazowe;

    PROCEDURE dodaj_rodzaj_produktu(p_nazwa VARCHAR2, p_dni_zdatnosci NUMBER, p_koszt_produkcji NUMBER) IS
    BEGIN
        INSERT INTO rodzaje_produktow VALUES (
            t_rodzaj_produktu(p_nazwa, p_dni_zdatnosci, p_koszt_produkcji)
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Dodano nowy rodzaj produktu: ' || p_nazwa);
    END dodaj_rodzaj_produktu;

    PROCEDURE usun_rodzaj_produktu(p_id_rodzaju NUMBER) IS
    BEGIN
        DELETE FROM rodzaje_produktow WHERE id_rodzaju = p_id_rodzaju;
        IF SQL%ROWCOUNT > 0 THEN COMMIT; DBMS_OUTPUT.PUT_LINE('Usunięto produkt ID: ' || p_id_rodzaju);
        ELSE DBMS_OUTPUT.PUT_LINE('Nie znaleziono produktu ID: ' || p_id_rodzaju); END IF;
    END usun_rodzaj_produktu;

    PROCEDURE dodaj_rodzaj_surowca(
        p_nazwa VARCHAR2, p_dni_zdatnosci NUMBER, 
        p_kcal NUMBER DEFAULT 0, p_bialko NUMBER DEFAULT 0, 
        p_wegle NUMBER DEFAULT 0, p_tluszcz NUMBER DEFAULT 0
    ) IS
    BEGIN
        INSERT INTO rodzaje_surowcow VALUES (
            t_rodzaj_surowca(p_nazwa, p_dni_zdatnosci, p_kcal, p_bialko, p_wegle, p_tluszcz)
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Sukces: Dodano surowiec: ' || p_nazwa);
    END dodaj_rodzaj_surowca;

    PROCEDURE usun_rodzaj_surowca(p_id_surowca NUMBER) IS
    BEGIN
        DELETE FROM rodzaje_surowcow WHERE id_rodzaju = p_id_surowca;
        IF SQL%ROWCOUNT > 0 THEN COMMIT; DBMS_OUTPUT.PUT_LINE('Usunięto rodzaj surowca ID: ' || p_id_surowca);
        ELSE DBMS_OUTPUT.PUT_LINE('Nie znaleziono rodzaju surowca ID: ' || p_id_surowca); END IF;
    END usun_rodzaj_surowca;

    PROCEDURE wyswietl_bilans_zyskow_strat IS
        v_przychody_sprzedaz NUMBER := 0;
        v_koszty_surowcow    NUMBER := 0;
        v_koszty_produkcji   NUMBER := 0;
        v_zysk_calkowity     NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(kwota), 0) INTO v_przychody_sprzedaz 
        FROM dostawy 
        WHERE czy_wychodzaca = 1;

        SELECT NVL(SUM(kwota), 0) INTO v_koszty_surowcow 
        FROM dostawy 
        WHERE czy_wychodzaca = 0;

        SELECT NVL(SUM(koszt), 0) INTO v_koszty_produkcji
        FROM partie_produktow;

        v_zysk_calkowity := v_przychody_sprzedaz - (v_koszty_surowcow + v_koszty_produkcji);

        DBMS_OUTPUT.PUT_LINE('--- BILANS FINANSOWY ---');
        DBMS_OUTPUT.PUT_LINE('(+) Przychody ze sprzedaży: ' || TO_CHAR(v_przychody_sprzedaz, '999G999D99') || ' PLN');
        DBMS_OUTPUT.PUT_LINE('(-) Koszty zakupu surowców: ' || TO_CHAR(v_koszty_surowcow, '999G999D99') || ' PLN');
        DBMS_OUTPUT.PUT_LINE('(-) Koszty produkcji (oper.): ' || TO_CHAR(v_koszty_produkcji, '999G999D99') || ' PLN');
        DBMS_OUTPUT.PUT_LINE('--------------------------');
        DBMS_OUTPUT.PUT_LINE('(=) WYNIK FINANSOWY:        ' || TO_CHAR(v_zysk_calkowity, '999G999D99') || ' PLN');
        
        IF v_zysk_calkowity > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Status: ZYSK');
        ELSIF v_zysk_calkowity < 0 THEN
            DBMS_OUTPUT.PUT_LINE('Status: STRATA');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Status: ZERO');
        END IF;
    END wyswietl_bilans_zyskow_strat;

    PROCEDURE wyswietl_rodzaje_produktow IS
        CURSOR c_prod IS SELECT id_rodzaju, nazwa_rodzaju, czas_zdatnosci, koszt_produkcji FROM rodzaje_produktow ORDER BY id_rodzaju;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        DBMS_OUTPUT.PUT_LINE(RPAD('ID', 5) || RPAD('NAZWA PRODUKTU', 30) || RPAD('ZDATNOSC', 10) || 'KOSZT PROD.');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        FOR r IN c_prod LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.id_rodzaju, 5) || 
                RPAD(r.nazwa_rodzaju, 30) || 
                RPAD(r.czas_zdatnosci || ' dni', 10) || 
                TRIM(TO_CHAR(r.koszt_produkcji, '99990.00')) || ' PLN'
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    END wyswietl_rodzaje_produktow;

    PROCEDURE wyswietl_rodzaje_surowcow IS
        CURSOR c_sur IS SELECT id_rodzaju, nazwa_surowca, czas_przydatnosci, wartosci FROM rodzaje_surowcow ORDER BY id_rodzaju;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        DBMS_OUTPUT.PUT_LINE(RPAD('ID', 5) || RPAD('NAZWA SUROWCA', 30) || RPAD('ZDATNOSC', 10) || 'KCAL/100g');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        FOR r IN c_sur LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.id_rodzaju, 5) || 
                RPAD(r.nazwa_surowca, 30) || 
                RPAD(r.czas_przydatnosci || ' dni', 10) || 
                r.wartosci.kcal
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    END wyswietl_rodzaje_surowcow;

    PROCEDURE wyswietl_kontrahentow IS
        CURSOR c_kontr IS SELECT id_kontrahenta, nazwa_firmy, adres_email FROM kontrahenci ORDER BY id_kontrahenta;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        DBMS_OUTPUT.PUT_LINE(RPAD('ID', 5) || RPAD('NAZWA FIRMY', 30) || 'E-MAIL');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        FOR r IN c_kontr LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.id_kontrahenta, 5) || 
                RPAD(r.nazwa_firmy, 30) || 
                r.adres_email
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    END wyswietl_kontrahentow;

    PROCEDURE wyswietl_kontrakty IS
        CURSOR c_kontrakty IS
            SELECT 
                k.id_kontraktu,
                k.czy_wychodzacy,
                DEREF(k.kontrahent_ref).nazwa_firmy AS kontrahent,
                CASE 
                    WHEN k.czy_wychodzacy = 0 THEN 
                        (SELECT s.nazwa_surowca FROM rodzaje_surowcow s WHERE REF(s) = k.surowiec_ref)
                    ELSE 
                        (SELECT p.nazwa_rodzaju FROM rodzaje_produktow p WHERE REF(p) = k.produkt_ref)
                END AS przedmiot,
                k.ilosc_planowa_g,
                k.cyklicznosc, 
                k.data_wygasniecia
            FROM kontrakty k
            ORDER BY k.id_kontraktu;
            
        v_typ_str VARCHAR2(10);
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
        DBMS_OUTPUT.PUT_LINE(
            RPAD('ID', 4) || RPAD('TYP', 8) || RPAD('KONTRAHENT', 20) || 
            RPAD('PRZEDMIOT', 20) || RPAD('ILOSC(g)', 10) || RPAD('CYKL', 15) || 'WYGASA'
        );
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));

        FOR r IN c_kontrakty LOOP
            IF r.czy_wychodzacy = 0 THEN v_typ_str := 'KUPNO';
            ELSE v_typ_str := 'SPRZEDAZ'; END IF;

            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.id_kontraktu, 4) || 
                RPAD(v_typ_str, 8) || 
                RPAD(SUBSTR(r.kontrahent, 1, 19), 20) || 
                RPAD(SUBSTR(r.przedmiot, 1, 19), 20) || 
                RPAD(r.ilosc_planowa_g, 10) || 
                RPAD(SUBSTR(r.cyklicznosc, 1, 14), 15) || 
                TO_CHAR(r.data_wygasniecia, 'YYYY-MM-DD')
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 100, '-'));
    END wyswietl_kontrakty;

END pkg_kierownik;
/
