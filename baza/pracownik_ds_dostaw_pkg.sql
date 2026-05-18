CREATE OR REPLACE TRIGGER trg_audyt_dostaw
AFTER INSERT ON dostawy
FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE('>>> TRIGGER AUDYTOWY: Zarejestrowano dostawę nr ' || :NEW.id_dostawy || ' w ilości ' || :NEW.faktyczna_ilosc);
END;
/

CREATE OR REPLACE PACKAGE pkg_pracownik_dostaw AS
    FUNCTION  sprawdz_mozliwosc_produkcji(p_id_rodzaju NUMBER) RETURN NUMBER;
    FUNCTION sprawdz_mozliwosc_kontraktu(p_id_kontraktu NUMBER) RETURN NUMBER;
    PROCEDURE rejestruj_dostawe(p_id_kontraktu NUMBER, p_faktyczna_ilosc NUMBER);
    PROCEDURE rejestruj_produkcje(p_id_rodzaju NUMBER, p_ilosc_sztuk NUMBER);
    PROCEDURE wyswietl_stan_magazynu;
    PROCEDURE wyswietl_kontrakty;
    PROCEDURE wyswietl_receptury;
    PROCEDURE wyswietl_statystyki_produkcji;
    PROCEDURE wyswietl_statystyki_kontraktow;
END pkg_pracownik_dostaw;
/


CREATE OR REPLACE PACKAGE BODY pkg_pracownik_dostaw AS

    FUNCTION pobierz_magazyn RETURN t_magazyn IS
        v_mag t_magazyn;
    BEGIN
        SELECT VALUE(m) INTO v_mag FROM magazyn m WHERE ROWNUM = 1 FOR UPDATE;
        RETURN v_mag;
    END;

    FUNCTION sprawdz_mozliwosc_produkcji(p_id_rodzaju NUMBER) RETURN NUMBER IS
        v_mag          t_magazyn;
        v_rodzaj       t_rodzaj_produktu;
        v_min_sztuk    NUMBER := 999999999;
        v_dostepne_sur NUMBER;
        v_limit_sur    NUMBER;
        v_temp_sur     t_rodzaj_surowca;
    BEGIN
        v_mag := pobierz_magazyn();

        BEGIN
            SELECT VALUE(r) INTO v_rodzaj 
            FROM rodzaje_produktow r 
            WHERE id_rodzaju = p_id_rodzaju;
        EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 0;
        END;

        IF v_rodzaj.receptura.skladniki IS NULL OR v_rodzaj.receptura.skladniki.COUNT = 0 THEN
            RETURN 0;
        END IF;

        FOR i IN 1 .. v_rodzaj.receptura.skladniki.COUNT LOOP
            SELECT DEREF(v_rodzaj.receptura.skladniki(i).rodzaj_surowca_ref) INTO v_temp_sur FROM DUAL;
            v_dostepne_sur := v_mag.sprawdz_stan(1, v_temp_sur.id_rodzaju);
            v_limit_sur := FLOOR(v_dostepne_sur / v_rodzaj.receptura.skladniki(i).ilosc_g);
            IF v_limit_sur < v_min_sztuk THEN
                v_min_sztuk := v_limit_sur;
            END IF;
        END LOOP;

        IF v_min_sztuk = 999999999 THEN RETURN 0; END IF;
        RETURN v_min_sztuk;
    END sprawdz_mozliwosc_produkcji;

    FUNCTION sprawdz_mozliwosc_kontraktu(p_id_kontraktu NUMBER) RETURN NUMBER IS
        v_mag          t_magazyn;
        v_kontrakt     t_kontrakt;
        v_prod         t_rodzaj_produktu;
        v_stan_prod    NUMBER;
    BEGIN
        v_mag := pobierz_magazyn();
        BEGIN
            SELECT VALUE(k) INTO v_kontrakt FROM kontrakty k WHERE id_kontraktu = p_id_kontraktu;
        EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 0; END;

        IF v_kontrakt.czy_wychodzacy = 0 THEN
            RETURN -1; 
        END IF;

        SELECT DEREF(v_kontrakt.produkt_ref) INTO v_prod FROM DUAL;
        v_stan_prod := v_mag.sprawdz_stan(0, v_prod.id_rodzaju);
        RETURN FLOOR(v_stan_prod / v_kontrakt.ilosc_planowa_g);
    END sprawdz_mozliwosc_kontraktu;

    PROCEDURE rejestruj_dostawe(p_id_kontraktu NUMBER, p_faktyczna_ilosc NUMBER) IS
        v_k_ref           REF t_kontrakt;
        v_kontrakt        t_kontrakt;
        v_mag             t_magazyn;
        v_dostawa         t_dostawa;
        v_temp_produkt    t_rodzaj_produktu;
        v_nowe_id_surowca NUMBER;

        CURSOR c_rodzaj(p_rodzaj_ref REF t_rodzaj_produktu) IS
            SELECT p.id_pola, p.ilosc
            FROM TABLE(SELECT m.pola FROM magazyn m) p
            WHERE p.czy_surowiec = 0
              AND (SELECT rodzaj_ref FROM partie_produktow pp WHERE REF(pp) = p.partia_ref) = p_rodzaj_ref
              AND (SELECT data_waznosci FROM partie_produktow pp WHERE REF(pp) = p.partia_ref) >= SYSDATE
            ORDER BY (SELECT data_waznosci FROM partie_produktow pp WHERE REF(pp) = p.partia_ref) ASC;

        v_do_pobrania  NUMBER;
        v_pobrano      NUMBER;
        v_licznik      NUMBER;
    BEGIN
        SELECT REF(k), VALUE(k) INTO v_k_ref, v_kontrakt FROM kontrakty k WHERE id_kontraktu = p_id_kontraktu;
        v_mag := pobierz_magazyn();

        SELECT COUNT(*) INTO v_licznik FROM dostawy WHERE kontrakt_ref = v_k_ref AND data_realizacji >= SYSDATE - v_kontrakt.cyklicznosc;
            IF v_licznik >= v_kontrakt.ile_dostaw_w_cyklu THEN
                RAISE_APPLICATION_ERROR(-20102, 'Przekroczono limit dostaw w cyklu!');
            END IF;

        IF v_kontrakt.czy_wychodzacy = 1 THEN
            SELECT DEREF(v_kontrakt.produkt_ref) INTO v_temp_produkt FROM DUAL;
             IF v_mag.sprawdz_stan(0, v_temp_produkt.id_rodzaju) < p_faktyczna_ilosc THEN
                 RAISE_APPLICATION_ERROR(-20101, 'Brak wystarczającej ilości towaru na magazynie!');
             END IF;

             v_do_pobrania := p_faktyczna_ilosc;

             FOR r IN c_rodzaj(v_kontrakt.produkt_ref) LOOP
                 EXIT WHEN v_do_pobrania <= 0;

                 IF r.ilosc >= v_do_pobrania THEN 
                    v_pobrano := v_do_pobrania;
                 ELSE 
                    v_pobrano := r.ilosc; 
                 END IF;

                 v_mag.usun_zasob(r.id_pola, v_pobrano);
                 v_do_pobrania := v_do_pobrania - v_pobrano;
             END LOOP;

             INSERT INTO dostawy VALUES (t_dostawa(v_k_ref, p_faktyczna_ilosc));

             UPDATE magazyn m SET VALUE(m) = v_mag;
             COMMIT;
             DBMS_OUTPUT.PUT_LINE('Sprzedaż zrealizowana.');
        ELSE 
            INSERT INTO dostawy VALUES (t_dostawa(v_k_ref, p_faktyczna_ilosc));
            
            INSERT INTO surowce_mleczarskie 
            VALUES (t_surowiec_mleczarski(v_kontrakt.surowiec_ref))
            RETURNING id_surowca INTO v_nowe_id_surowca;

            v_mag.przyjmij_z_dostawy(v_nowe_id_surowca, p_faktyczna_ilosc);

            UPDATE magazyn m SET VALUE(m) = v_mag;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Dostawa surowca przyjęta. Utworzono surowiec ID: ' || v_nowe_id_surowca);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Błąd: Nie znaleziono kontraktu.');
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END rejestruj_dostawe;

    PROCEDURE rejestruj_produkcje(p_id_rodzaju NUMBER, p_ilosc_sztuk NUMBER) IS
        v_mag              t_magazyn;
        v_r_ref            REF t_rodzaj_produktu;
        v_rodzaj           t_rodzaj_produktu;
        v_stan_sur         NUMBER;
        v_potrzebna_ilosc  NUMBER;
        v_szukany_surowiec REF t_rodzaj_surowca;
        v_do_usuniecia     NUMBER;
        v_dostepne_na_polu NUMBER;
        v_temp_surowiec    t_rodzaj_surowca;
        v_nowa_partia_id   NUMBER;

         CURSOR c_rodzaj(p_rodzaj_ref REF t_rodzaj_surowca) IS
            SELECT p.id_pola, p.ilosc
            FROM TABLE(SELECT m.pola FROM magazyn m) p
            WHERE p.czy_surowiec = 1
              AND (SELECT rodzaj_ref FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref) = p_rodzaj_ref
              AND (SELECT data_waznosci FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref) >= SYSDATE
            ORDER BY (SELECT data_waznosci FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref) ASC;

    BEGIN
        v_mag := pobierz_magazyn();
        SELECT REF(r), VALUE(r) INTO v_r_ref, v_rodzaj FROM rodzaje_produktow r WHERE id_rodzaju = p_id_rodzaju;

        FOR i IN 1..v_rodzaj.receptura.skladniki.COUNT LOOP
            SELECT DEREF(v_rodzaj.receptura.skladniki(i).rodzaj_surowca_ref) INTO v_temp_surowiec FROM DUAL;
             v_stan_sur := v_mag.sprawdz_stan(1, v_temp_surowiec.id_rodzaju);
             IF v_stan_sur < (v_rodzaj.receptura.skladniki(i).ilosc_g * p_ilosc_sztuk) THEN
                 RAISE_APPLICATION_ERROR(-20103, 'Brakuje surowca do produkcji!');
             END IF;
        END LOOP;

        FOR i IN 1..v_rodzaj.receptura.skladniki.COUNT LOOP
            v_szukany_surowiec := v_rodzaj.receptura.skladniki(i).rodzaj_surowca_ref;
            v_potrzebna_ilosc  := v_rodzaj.receptura.skladniki(i).ilosc_g * p_ilosc_sztuk;
            FOR r IN c_rodzaj(v_szukany_surowiec) LOOP
                EXIT WHEN v_potrzebna_ilosc <= 0;

               IF r.ilosc >= v_potrzebna_ilosc THEN 
                    v_do_usuniecia := v_potrzebna_ilosc;
                ELSE 
                    v_do_usuniecia := r.ilosc; 
                END IF;

                v_mag.usun_zasob(r.id_pola, v_do_usuniecia);
                v_potrzebna_ilosc := v_potrzebna_ilosc - v_do_usuniecia;
            END LOOP;
        END LOOP;

        INSERT INTO partie_produktow 
        VALUES (t_partia_produktu(v_r_ref, SYSDATE))
        RETURNING numer_partii INTO v_nowa_partia_id;

        v_mag.przyjmij_z_produkcji(v_nowa_partia_id, p_ilosc_sztuk);

        UPDATE magazyn m SET VALUE(m) = v_mag;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Produkcja zarejestrowana.');
    END rejestruj_produkcje;

    PROCEDURE wyswietl_stan_magazynu IS
        v_mag t_magazyn;
    BEGIN
        SELECT VALUE(m) INTO v_mag FROM magazyn m WHERE ROWNUM = 1; 
        v_mag.wypisz_stan_produktow();
    END wyswietl_stan_magazynu;

    PROCEDURE wyswietl_kontrakty IS
       CURSOR c IS SELECT id_kontraktu, ilosc_planowa_g, cena_za_100_gram FROM kontrakty;
    BEGIN
       FOR r IN c LOOP
           DBMS_OUTPUT.PUT_LINE('Kontrakt ID: ' || r.id_kontraktu || ' | Ilość: ' || r.ilosc_planowa_g || 'g');
       END LOOP;
    END wyswietl_kontrakty;

    PROCEDURE wyswietl_receptury IS
        CURSOR c_produkty IS 
            SELECT id_rodzaju, nazwa_rodzaju, receptura 
            FROM rodzaje_produktow 
            ORDER BY id_rodzaju;

        v_surowiec t_rodzaj_surowca;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));
        DBMS_OUTPUT.PUT_LINE(' KATALOG PRODUKTÓW I RECEPTUR');
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));

        FOR r_prod IN c_produkty LOOP
            DBMS_OUTPUT.PUT_LINE('PRODUKT [' || r_prod.id_rodzaju || ']: ' || r_prod.nazwa_rodzaju);
            IF r_prod.receptura.skladniki IS NOT NULL AND r_prod.receptura.skladniki.COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Składniki (na 1 sztukę):');
                FOR i IN 1..r_prod.receptura.skladniki.COUNT LOOP
                    IF r_prod.receptura.skladniki.EXISTS(i) THEN
                        SELECT DEREF(r_prod.receptura.skladniki(i).rodzaj_surowca_ref) INTO v_surowiec FROM DUAL;
                        DBMS_OUTPUT.PUT_LINE(
                            '    - ' || RPAD(v_surowiec.nazwa_surowca, 30) || 
                            ': ' || r_prod.receptura.skladniki(i).ilosc_g || 'g'
                        );
                    END IF;
                END LOOP;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  [!] Brak zdefiniowanej receptury.');
            END IF;
            DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
        END LOOP;
    END wyswietl_receptury;

    PROCEDURE wyswietl_statystyki_produkcji IS
        CURSOR c_prod IS SELECT id_rodzaju, nazwa_rodzaju FROM rodzaje_produktow ORDER BY id_rodzaju;
        v_ile NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));
        DBMS_OUTPUT.PUT_LINE(' MOŻLIWOŚCI PRODUKCYJNE (wg stanu surowców)');
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));
        DBMS_OUTPUT.PUT_LINE(RPAD('PRODUKT', 40) || 'MOŻLIWA ILOŚĆ (szt.)');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));

        FOR r IN c_prod LOOP
            v_ile := sprawdz_mozliwosc_produkcji(r.id_rodzaju);

            IF v_ile > 0 THEN
                DBMS_OUTPUT.PUT_LINE(RPAD(r.nazwa_rodzaju, 40) || v_ile);
            ELSE
                DBMS_OUTPUT.PUT_LINE(RPAD(r.nazwa_rodzaju, 40) || '0 (Brak surowców)');
            END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));
    END wyswietl_statystyki_produkcji;

    PROCEDURE wyswietl_statystyki_kontraktow IS
        CURSOR c_kontr IS 
            SELECT k.id_kontraktu, DEREF(k.kontrahent_ref).nazwa_firmy as klient, k.czy_wychodzacy 
            FROM kontrakty k 
            WHERE k.czy_wychodzacy = 1
            ORDER BY k.id_kontraktu;

        v_ile NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
        DBMS_OUTPUT.PUT_LINE(' MOŻLIWOŚCI REALIZACJI ZAMÓWIEŃ (SPRZEDAŻ)');
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
        DBMS_OUTPUT.PUT_LINE(RPAD('ID', 5) || RPAD('KLIENT', 30) || 'STATUS / POKRYCIE');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
        FOR r IN c_kontr LOOP
            v_ile := sprawdz_mozliwosc_kontraktu(r.id_kontraktu);

            IF v_ile >= 1 THEN
                DBMS_OUTPUT.PUT_LINE(
                    RPAD(r.id_kontraktu, 5) || 
                    RPAD(SUBSTR(r.klient,1,28), 30) || 
                    'GOTOWE (x' || v_ile || ')'
                );
            ELSE
                DBMS_OUTPUT.PUT_LINE(
                    RPAD(r.id_kontraktu, 5) || 
                    RPAD(SUBSTR(r.klient,1,28), 30) || 
                    'BRAKI MAGAZYNOWE'
                );
            END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
    END wyswietl_statystyki_kontraktow;

END pkg_pracownik_dostaw;
/
