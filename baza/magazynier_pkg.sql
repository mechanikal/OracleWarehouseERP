CREATE OR REPLACE PACKAGE pkg_magazynier AS
    PROCEDURE wyswietl_stan_magazynu;
    PROCEDURE usun_pole_magazynowe(p_id_pola NUMBER);
    PROCEDURE raport_przeterminowane(p_cursor OUT SYS_REFCURSOR);
END pkg_magazynier;
/

CREATE OR REPLACE TRIGGER trg_zmiana_stanu_magazynu
AFTER UPDATE ON magazyn
BEGIN
    DBMS_OUTPUT.PUT_LINE('LOG SYSTEMOWY: Zmodyfikowano stan magazynowy.');
END;
/

CREATE OR REPLACE PACKAGE BODY pkg_magazynier AS
    PROCEDURE wyswietl_stan_magazynu IS
        v_mag t_magazyn;
    BEGIN
        SELECT VALUE(m) INTO v_mag FROM magazyn m;
        v_mag.wypisz_stan_produktow();
    END;

    PROCEDURE usun_pole_magazynowe(p_id_pola NUMBER) IS
        v_mag              t_magazyn;
        v_ilosc_na_stanie  NUMBER;
        v_znaleziono       BOOLEAN := FALSE;
    BEGIN
        SELECT VALUE(m) INTO v_mag FROM magazyn m WHERE ROWNUM = 1 FOR UPDATE;

        IF v_mag.pola IS NOT NULL THEN
            FOR i IN 1..v_mag.pola.COUNT LOOP
                IF v_mag.pola.EXISTS(i) AND v_mag.pola(i).id_pola = p_id_pola THEN
                    v_ilosc_na_stanie := v_mag.pola(i).ilosc;
                    v_znaleziono := TRUE;
                    EXIT;
                END IF;
            END LOOP;
        END IF;

        IF v_znaleziono THEN
            v_mag.usun_zasob(p_id_pola, v_ilosc_na_stanie);
            UPDATE magazyn m SET VALUE(m) = v_mag;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Usunięto pole ID: ' || p_id_pola || ' (usunięto ' || v_ilosc_na_stanie || ' jednostek).');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Nie znaleziono pola o ID: ' || p_id_pola);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Błąd podczas usuwania pola: ' || SQLERRM);
    END;

    PROCEDURE raport_przeterminowane(p_cursor OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT p.id_pola, 
                   'PRODUKT' as typ,
                   (SELECT nazwa_rodzaju FROM rodzaje_produktow r 
                    WHERE REF(r) = (SELECT rodzaj_ref FROM partie_produktow pp WHERE REF(pp) = p.partia_ref)) as nazwa,
                   (SELECT data_waznosci FROM partie_produktow pp WHERE REF(pp) = p.partia_ref) as data_waznosci
            FROM TABLE(SELECT m.pola FROM magazyn m) p
            WHERE p.czy_surowiec = 0
              AND (SELECT data_waznosci FROM partie_produktow pp WHERE REF(pp) = p.partia_ref) < SYSDATE
            
            UNION ALL
            
            SELECT p.id_pola,
                   'SUROWIEC' as typ,
                   (SELECT nazwa_surowca FROM rodzaje_surowcow s 
                   WHERE REF(s) = (SELECT rodzaj_ref FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref)) as nazwa,
                   (SELECT data_waznosci FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref) as data_waznosci
            FROM TABLE(SELECT m.pola FROM magazyn m) p
            WHERE p.czy_surowiec = 1
              AND (SELECT data_waznosci FROM surowce_mleczarskie sm WHERE REF(sm) = p.surowiec_ref) < SYSDATE;
                   
        DBMS_OUTPUT.PUT_LINE('Kursor z raportem przeterminowanych został otwarty.');
    END;

END pkg_magazynier;
/
