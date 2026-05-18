-------------------WARTOŚCI OŻYWCZE-------------------

CREATE SEQUENCE seq_wartosci START WITH 1;

CREATE OR REPLACE TYPE t_wartosci_odzywcze AS OBJECT(
    id_wartosci   NUMBER,
    kcal          NUMBER,
    bialka        NUMBER,
    weglowodany   NUMBER,
    tluszcze      NUMBER,

    CONSTRUCTOR FUNCTION t_wartosci_odzywcze(
        p_kcal         NUMBER DEFAULT 0,
        p_bialka       NUMBER DEFAULT 0,
        p_weglowodany  NUMBER DEFAULT 0,
        p_tluszcze     NUMBER DEFAULT 0
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_wartosci_odzywcze AS

    CONSTRUCTOR FUNCTION t_wartosci_odzywcze(
        p_kcal         NUMBER DEFAULT 0,
        p_bialka       NUMBER DEFAULT 0,
        p_weglowodany  NUMBER DEFAULT 0,
        p_tluszcze     NUMBER DEFAULT 0
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF (p_bialka + p_weglowodany + p_tluszcze) > 100 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Suma makroskładników przekracza 100g!');
        END IF;

        SELF.id_wartosci  := seq_wartosci.NEXTVAL;
        SELF.kcal         := p_kcal;
        SELF.bialka       := p_bialka;
        SELF.weglowodany  := p_weglowodany;
        SELF.tluszcze     := p_tluszcze;
        RETURN;
    END;
    
END;
/

-------------------ROZAJE SUROWCÓW-------------------

CREATE SEQUENCE seq_surowiec_rodzaj START WITH 1;

CREATE OR REPLACE TYPE t_rodzaj_surowca AS OBJECT (
    id_rodzaju        NUMBER,
    nazwa_surowca     VARCHAR2(100),
    czas_przydatnosci NUMBER,
    wartosci          t_wartosci_odzywcze,

    CONSTRUCTOR FUNCTION t_rodzaj_surowca(
        p_nazwa_surowca     VARCHAR2,
        p_czas_dni          NUMBER,
        p_kcal              NUMBER DEFAULT 0,
        p_bialka            NUMBER DEFAULT 0,
        p_weglowodany       NUMBER DEFAULT 0,
        p_tluszcze          NUMBER DEFAULT 0
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_rodzaj_surowca AS
    CONSTRUCTOR FUNCTION t_rodzaj_surowca(
        p_nazwa_surowca     VARCHAR2,
        p_czas_dni          NUMBER,
        p_kcal              NUMBER DEFAULT 0,
        p_bialka            NUMBER DEFAULT 0,
        p_weglowodany       NUMBER DEFAULT 0,
        p_tluszcze          NUMBER DEFAULT 0
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF p_czas_dni <= 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Produkt nieprzydatny do użytku!!!');
        END IF;
        SELF.id_rodzaju        := seq_surowiec_rodzaj.NEXTVAL;
        SELF.nazwa_surowca     := p_nazwa_surowca;
        SELF.czas_przydatnosci := p_czas_dni;
        SELF.wartosci          := t_wartosci_odzywcze(p_kcal, p_bialka, p_weglowodany, p_tluszcze);
        RETURN;
    END;
END;
/

CREATE TABLE rodzaje_surowcow OF t_rodzaj_surowca(
    CONSTRAINT pk_rodzaj_surowca PRIMARY KEY (id_rodzaju),
    nazwa_surowca NOT NULL
);

-------------------SUROWCE-------------------

CREATE SEQUENCE seq_surowiec START WITH 1;

CREATE OR REPLACE TYPE t_surowiec_mleczarski AS OBJECT(
    id_surowca      NUMBER,
    rodzaj_ref      REF t_rodzaj_surowca,
    data_dostawy    DATE,
    data_waznosci   DATE,

    CONSTRUCTOR FUNCTION t_surowiec_mleczarski(
        p_rodzaj_ref REF t_rodzaj_surowca
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_surowiec_mleczarski AS
    CONSTRUCTOR FUNCTION t_surowiec_mleczarski(
        p_rodzaj_ref REF t_rodzaj_surowca
    ) RETURN SELF AS RESULT IS
        v_rodzaj t_rodzaj_surowca;
    BEGIN
        IF p_rodzaj_ref IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050, 'Należy podać referencję do rodzaju surowca.');
        END IF;

        SELECT DEREF(p_rodzaj_ref) INTO v_rodzaj FROM DUAL;

        SELF.id_surowca    := seq_surowiec.NEXTVAL;
        SELF.rodzaj_ref    := p_rodzaj_ref;
        SELF.data_dostawy  := SYSDATE;
        SELF.data_waznosci := SYSDATE + v_rodzaj.czas_przydatnosci;

        RETURN;
    END;
END;
/

CREATE TABLE surowce_mleczarskie OF t_surowiec_mleczarski(
    CONSTRAINT pk_surowiec PRIMARY KEY (id_surowca)
);

-------------------SKŁADNIKI-------------------

CREATE OR REPLACE TYPE t_skladnik AS OBJECT(
    rodzaj_surowca_ref REF t_rodzaj_surowca,
    ilosc_g      NUMBER,

    CONSTRUCTOR FUNCTION t_skladnik(
        p_rodzaj_surowca_ref REF t_rodzaj_surowca,
        p_ilosc_g      NUMBER
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_skladnik AS
    CONSTRUCTOR FUNCTION t_skladnik(
        p_rodzaj_surowca_ref REF t_rodzaj_surowca,
        p_ilosc_g      NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF p_ilosc_g <= 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Ilość surowca musi być większa od 0 gramów!');
        END IF;
        SELF.rodzaj_surowca_ref := p_rodzaj_surowca_ref;
        SELF.ilosc_g      := p_ilosc_g;
        RETURN;
    END;
END;
/

CREATE OR REPLACE TYPE t_lista_skladnikow AS TABLE OF t_skladnik;
/

-------------------RECEPTURY-------------------

CREATE SEQUENCE seq_receptury START WITH 1;

CREATE OR REPLACE TYPE t_receptura AS OBJECT(
    id_receptury      NUMBER,
    skladniki         t_lista_skladnikow,

    CONSTRUCTOR FUNCTION t_receptura(
        p_skladniki   t_lista_skladnikow
    ) RETURN SELF AS RESULT,

    MEMBER PROCEDURE dodaj_skladnik(p_id_rodzaju NUMBER, p_ilosc NUMBER),
    MEMBER PROCEDURE usun_skladnik(p_id_rodzaju NUMBER)
);
/

CREATE OR REPLACE TYPE BODY t_receptura AS
    CONSTRUCTOR FUNCTION t_receptura(
        p_skladniki   t_lista_skladnikow
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF p_skladniki IS NULL THEN
            RAISE_APPLICATION_ERROR(-20040, 'należy podać listę składników');
        END IF;
        SELF.id_receptury := seq_receptury.NEXTVAL;
        SELF.skladniki    := p_skladniki;
        RETURN;
    END;

    MEMBER PROCEDURE dodaj_skladnik(p_id_rodzaju NUMBER, p_ilosc NUMBER) IS
    v_rodzaj_surowca_ref REF t_rodzaj_surowca;
    BEGIN
        BEGIN
            SELECT REF(s) INTO v_rodzaj_surowca_ref 
            FROM rodzaje_surowcow s 
            WHERE s.id_rodzaju = p_id_rodzaju;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20005, 'Nie znaleziono rodzaju surowca o ID: ' || p_id_rodzaju);
        END;

        IF SELF.skladniki IS NULL THEN
            SELF.skladniki := t_lista_skladnikow();
        END IF;

        IF SELF.skladniki.COUNT > 0 THEN
            FOR i IN 1 .. SELF.skladniki.LAST LOOP
                IF SELF.skladniki.EXISTS(i) THEN
                    IF SELF.skladniki(i).rodzaj_surowca_ref = v_rodzaj_surowca_ref THEN
                    SELF.skladniki(i).ilosc_g := SELF.skladniki(i).ilosc_g + p_ilosc;
                        RETURN;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        SELF.skladniki.EXTEND;
        SELF.skladniki(SELF.skladniki.LAST) := t_skladnik(
            p_rodzaj_surowca_ref => v_rodzaj_surowca_ref, 
            p_ilosc_g      => p_ilosc
        ); 
    END;

    MEMBER PROCEDURE usun_skladnik(p_id_rodzaju NUMBER) IS
    v_rodzaj_surowca_ref REF t_rodzaj_surowca;
    BEGIN
        BEGIN
            SELECT REF(s) INTO v_rodzaj_surowca_ref 
            FROM rodzaje_surowcow s 
            WHERE s.id_rodzaju = p_id_rodzaju;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN;
        END;

        IF SELF.skladniki IS NOT NULL AND SELF.skladniki.COUNT > 0 THEN
            FOR i IN 1 .. SELF.skladniki.LAST LOOP
                IF SELF.skladniki.EXISTS(i) THEN
                    IF SELF.skladniki(i).rodzaj_surowca_ref = v_rodzaj_surowca_ref THEN
                        SELF.skladniki.DELETE(i);
                        RETURN;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END;
END;
/

-------------------RODZAJ PRODUKTU-------------------

CREATE SEQUENCE seq_rodzaj START WITH 1;

CREATE OR REPLACE TYPE t_rodzaj_produktu AS OBJECT(
    id_rodzaju          NUMBER,
    nazwa_rodzaju       VARCHAR2(100),
    czas_zdatnosci      NUMBER,
    waga                NUMBER,
    koszt_produkcji     NUMBER,
    receptura           t_receptura,
    wartosci_odzywcze   t_wartosci_odzywcze,

    CONSTRUCTOR FUNCTION t_rodzaj_produktu(
        p_nazwa_rodzaju     VARCHAR2,
        p_dni_zdatnosci     NUMBER,
        p_koszt_produkcji   NUMBER
    ) RETURN SELF AS RESULT,

    MEMBER PROCEDURE przelicz_wartosci,
    MEMBER PROCEDURE dodaj_skladnik(id_skladnika NUMBER, p_ilosc NUMBER),
    MEMBER PROCEDURE usun_skladnik(id_skladnika NUMBER)
);
/

CREATE OR REPLACE TYPE BODY t_rodzaj_produktu AS
    CONSTRUCTOR FUNCTION t_rodzaj_produktu(
        p_nazwa_rodzaju     VARCHAR2,
        p_dni_zdatnosci     NUMBER,
        p_koszt_produkcji   NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        SELF.id_rodzaju        := seq_rodzaj.NEXTVAL;
        SELF.nazwa_rodzaju     := p_nazwa_rodzaju;
        SELF.czas_zdatnosci    := p_dni_zdatnosci;
        SELF.koszt_produkcji   := p_koszt_produkcji;
        SELF.receptura         := t_receptura(t_lista_skladnikow());
        SELF.waga              := 0;
        SELF.wartosci_odzywcze := t_wartosci_odzywcze(0, 0, 0, 0);
        RETURN;
    END;

    MEMBER PROCEDURE przelicz_wartosci IS
        v_rodzaj_surowca    t_rodzaj_surowca;
        v_wartosci          t_wartosci_odzywcze;
        v_suma_waga         NUMBER := 0;
        v_suma_bialka       NUMBER := 0;
        v_suma_tluszcz      NUMBER := 0;
        v_suma_kcal         NUMBER := 0;
        v_suma_weglowodany  NUMBER := 0;
    BEGIN
        IF SELF.receptura.skladniki IS NOT NULL AND SELF.receptura.skladniki.COUNT > 0 THEN
            FOR i IN 1 .. SELF.receptura.skladniki.COUNT LOOP
                SELECT DEREF(SELF.receptura.skladniki(i).rodzaj_surowca_ref) INTO v_rodzaj_surowca FROM DUAL;
                v_wartosci         := v_rodzaj_surowca.wartosci;
                v_suma_waga        := v_suma_waga + SELF.receptura.skladniki(i).ilosc_g;
                v_suma_bialka      := v_suma_bialka + (SELF.receptura.skladniki(i).ilosc_g * v_wartosci.bialka / 100);
                v_suma_tluszcz     := v_suma_tluszcz + (SELF.receptura.skladniki(i).ilosc_g * v_wartosci.tluszcze / 100);
                v_suma_kcal        := v_suma_kcal + (SELF.receptura.skladniki(i).ilosc_g * v_wartosci.kcal / 100);
                v_suma_weglowodany := v_suma_weglowodany + (SELF.receptura.skladniki(i).ilosc_g * v_wartosci.weglowodany / 100);
            END LOOP;
        END IF;

        IF v_suma_waga > 0 THEN
            SELF.wartosci_odzywcze := t_wartosci_odzywcze(
                ROUND(v_suma_kcal, 2),
                ROUND((v_suma_bialka / v_suma_waga) * 100, 2),
                ROUND((v_suma_weglowodany / v_suma_waga) * 100, 2),
                ROUND((v_suma_tluszcz / v_suma_waga) * 100, 2)
            );
            SELF.waga := v_suma_waga;
        ELSE
            SELF.waga := 0;
            SELF.wartosci_odzywcze := t_wartosci_odzywcze(0, 0, 0, 0);
        END IF;
    END;

    MEMBER PROCEDURE dodaj_skladnik(id_skladnika NUMBER, p_ilosc NUMBER) IS
    BEGIN
        SELF.receptura.dodaj_skladnik(id_skladnika, p_ilosc);
        SELF.przelicz_wartosci;
    END;

    MEMBER PROCEDURE usun_skladnik(id_skladnika NUMBER) IS
    BEGIN
        SELF.receptura.usun_skladnik(id_skladnika);
        SELF.przelicz_wartosci;
    END;
END;
/

CREATE TABLE rodzaje_produktow OF t_rodzaj_produktu(
    CONSTRAINT pk_rodzaj_produktu PRIMARY KEY (id_rodzaju),
    CONSTRAINT uk_rodzaj_produktu_nazwa UNIQUE (nazwa_rodzaju)
)
NESTED TABLE receptura.skladniki STORE AS tabela_skladnikow_produktu;

-------------------PARTIA PRODUKTU-------------------

CREATE OR REPLACE TYPE t_partia_produktu AS OBJECT(
    numer_partii      NUMBER,
    rodzaj_ref        REF t_rodzaj_produktu,
    data_produkcji    DATE,
    data_waznosci     DATE,
    koszt             NUMBER,

    CONSTRUCTOR FUNCTION t_partia_produktu(
        p_rodzaj_ref      REF t_rodzaj_produktu,
        p_data_produkcji  DATE DEFAULT SYSDATE
    ) RETURN SELF AS RESULT
);
/

CREATE SEQUENCE seq_partie START WITH 1;

CREATE OR REPLACE TYPE BODY t_partia_produktu AS
    CONSTRUCTOR FUNCTION t_partia_produktu(
        p_rodzaj_ref      REF t_rodzaj_produktu,
        p_data_produkcji  DATE DEFAULT SYSDATE
    ) RETURN SELF AS RESULT IS
        v_rodzaj          t_rodzaj_produktu;
    BEGIN
        IF p_rodzaj_ref IS NULL THEN
            RAISE_APPLICATION_ERROR(-20008, 'Partia musi być przypisana do rodzaju produktu!');
        END IF;

        SELECT DEREF(p_rodzaj_ref) INTO v_rodzaj FROM DUAL;

        IF v_rodzaj IS NULL THEN
            RAISE_APPLICATION_ERROR(-20049, 'Podany rodzaj produktu nie istnieje (Dangling REF)!');
        END IF;

        SELF.numer_partii   := seq_partie.NEXTVAL;
        SELF.rodzaj_ref     := p_rodzaj_ref;
        SELF.data_produkcji := p_data_produkcji;
        SELF.data_waznosci  := p_data_produkcji + v_rodzaj.czas_zdatnosci;
        SELF.koszt          := v_rodzaj.koszt_produkcji;
        RETURN;
    END;
END;
/

CREATE TABLE partie_produktow OF t_partia_produktu(
    CONSTRAINT pk_partia PRIMARY KEY (numer_partii),
    rodzaj_ref SCOPE IS rodzaje_produktow NOT NULL,
    data_produkcji NOT NULL
);

ALTER TABLE partie_produktow 
ADD CONSTRAINT fk_partia_rodzaj 
FOREIGN KEY (rodzaj_ref) REFERENCES rodzaje_produktow;

-------------------KONTRAHENT-------------------

CREATE SEQUENCE seq_kontrahent START WITH 1;

CREATE OR REPLACE TYPE t_kontrahent AS OBJECT(
    id_kontrahenta    NUMBER,
    nazwa_firmy       VARCHAR2(100),
    numer_telefonu    VARCHAR2(20),
    adres_email       VARCHAR2(100),

    CONSTRUCTOR FUNCTION t_kontrahent(
        p_nazwa_firmy     VARCHAR2,
        p_numer_telefonu  VARCHAR2,
        p_adres_email     VARCHAR2
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_kontrahent AS
    CONSTRUCTOR FUNCTION t_kontrahent(
        p_nazwa_firmy     VARCHAR2,
        p_numer_telefonu  VARCHAR2,
        p_adres_email     VARCHAR2
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF p_nazwa_firmy IS NULL OR LENGTH(TRIM(p_nazwa_firmy)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Nazwa firmy nie może być pusta.');
        END IF;

        IF p_adres_email NOT LIKE '%@%.%' THEN
            RAISE_APPLICATION_ERROR(-20012, 'Niepoprawny format adresu e-mail.');
        END IF;

        SELF.id_kontrahenta := seq_kontrahent.NEXTVAL;
        SELF.nazwa_firmy    := p_nazwa_firmy;
        SELF.numer_telefonu := p_numer_telefonu;
        SELF.adres_email    := p_adres_email;
        RETURN;
    END;
END;
/

CREATE TABLE kontrahenci OF t_kontrahent(
    CONSTRAINT pk_kontrahent PRIMARY KEY (id_kontrahenta),
    nazwa_firmy NOT NULL,
    adres_email NOT NULL,
    CONSTRAINT unique_email UNIQUE (adres_email),
    CONSTRAINT unique_firma UNIQUE (nazwa_firmy)
);

-------------------KONTRAKT-------------------

CREATE OR REPLACE TYPE t_kontrakt AS OBJECT(
    id_kontraktu        NUMBER,
    kontrahent_ref      REF t_kontrahent,
    surowiec_ref        REF t_rodzaj_surowca,
    produkt_ref         REF t_rodzaj_produktu,
    data_sporzadzenia   DATE,
    data_wygasniecia    DATE,
    cyklicznosc         NUMBER,
    ile_dostaw_w_cyklu  NUMBER,
    cena_za_100_gram    NUMBER,
    ilosc_planowa_g     NUMBER,
    czy_wychodzacy      NUMBER(1),

    CONSTRUCTOR FUNCTION t_kontrakt(
        p_kontrahent_ref    REF t_kontrahent,
        p_id_przedmiotu     NUMBER,
        p_data_sporz        DATE DEFAULT SYSDATE,
        p_data_wygas        DATE,
        p_cykl              VARCHAR2,
        p_ile_w_cyklu       NUMBER,
        p_cena              NUMBER,
        p_ilosc             NUMBER,
        p_czy_wychodzacy    VARCHAR2
    ) RETURN SELF AS RESULT
);
/

CREATE SEQUENCE seq_kontrakt START WITH 1;

CREATE OR REPLACE TYPE BODY t_kontrakt AS
    CONSTRUCTOR FUNCTION t_kontrakt(
        p_kontrahent_ref    REF t_kontrahent,
        p_id_przedmiotu     NUMBER,
        p_data_sporz        DATE DEFAULT SYSDATE,
        p_data_wygas        DATE,
        p_cykl              VARCHAR2,
        p_ile_w_cyklu       NUMBER,
        p_cena              NUMBER,
        p_ilosc             NUMBER,
        p_czy_wychodzacy    VARCHAR2
    ) RETURN SELF AS RESULT IS
        v_cykl_upper        VARCHAR2(20);
        v_wychodzacy_upper  VARCHAR2(10);
    BEGIN
        IF p_data_wygas IS NOT NULL AND p_data_wygas < p_data_sporz THEN
            RAISE_APPLICATION_ERROR(-20013, 'Data wygaśnięcia nie może być wcześniejsza niż data sporządzenia.');
        END IF;

        IF p_cena <= 0 OR p_ilosc <= 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Cena i ilość planowa muszą być większe od zera.');
        END IF;

        v_cykl_upper := UPPER(p_cykl);
        IF v_cykl_upper LIKE 'DZIENNY' THEN
            SELF.cyklicznosc := 1;
        ELSIF v_cykl_upper LIKE 'TYGODNIOWY' THEN
            SELF.cyklicznosc := 7;
        ELSIF v_cykl_upper LIKE 'MIESIECZNY' THEN
            SELF.cyklicznosc := 30.5;
        ELSIF v_cykl_upper LIKE 'JEDNORAZOWY' THEN
            SELF.cyklicznosc := 999999;
        ELSE
            RAISE_APPLICATION_ERROR(-20015, 'Niepoprawna cykliczność. Wybierz: DZIENNY, TYGODNIOWY, MIESIECZNY lub JEDNORAZOWY.');
        END IF;

        SELF.produkt_ref := NULL;
        SELF.surowiec_ref := NULL;
        v_wychodzacy_upper := UPPER(p_czy_wychodzacy);
        IF v_wychodzacy_upper LIKE 'WYJ' THEN
            SELF.czy_wychodzacy := 1; 
            BEGIN
                SELECT REF(p) INTO SELF.produkt_ref
                FROM rodzaje_produktow p
                WHERE p.id_rodzaju = p_id_przedmiotu;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20016, 'Nie znaleziono rodzaju produktu o ID: ' || p_id_przedmiotu);
            END;
        ELSIF v_wychodzacy_upper LIKE 'WEJ' THEN
            SELF.czy_wychodzacy := 0; 
            BEGIN
                SELECT REF(s) INTO SELF.surowiec_ref
                FROM rodzaje_surowcow s
                WHERE s.id_rodzaju = p_id_przedmiotu;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20017, 'Nie znaleziono surowca o ID: ' || p_id_przedmiotu);
            END;
        ELSE
            RAISE_APPLICATION_ERROR(-20018, 'Niepoprawna parametr czy_wychodzący. Wybierz: WEJ/WYJ.');
        END IF;

        SELF.id_kontraktu       := seq_kontrakt.NEXTVAL;
        SELF.kontrahent_ref     := p_kontrahent_ref;
        SELF.data_sporzadzenia  := p_data_sporz;
        SELF.data_wygasniecia   := p_data_wygas;
        SELF.ile_dostaw_w_cyklu := p_ile_w_cyklu;
        SELF.cena_za_100_gram   := p_cena;
        SELF.ilosc_planowa_g    := p_ilosc;
        RETURN;
    END;
END;
/

CREATE TABLE kontrakty OF t_kontrakt(
    CONSTRAINT pk_kontrakt PRIMARY KEY (id_kontraktu),
    kontrahent_ref SCOPE IS kontrahenci NOT NULL,
    surowiec_ref SCOPE IS rodzaje_surowcow,
    produkt_ref SCOPE IS rodzaje_produktow,
    CONSTRAINT chk_kierunek CHECK(
        (czy_wychodzacy = 1 AND produkt_ref IS NOT NULL AND surowiec_ref IS NULL) OR
        (czy_wychodzacy = 0 AND surowiec_ref IS NOT NULL AND produkt_ref IS NULL)
    )
);

ALTER TABLE kontrakty 
ADD CONSTRAINT fk_kontrakt_kontrahent 
FOREIGN KEY (kontrahent_ref) REFERENCES kontrahenci;

ALTER TABLE kontrakty 
ADD CONSTRAINT fk_kontrakt_surowiec 
FOREIGN KEY (surowiec_ref) REFERENCES rodzaje_surowcow;

ALTER TABLE kontrakty 
ADD CONSTRAINT fk_kontrakt_rodzaj 
FOREIGN KEY (produkt_ref) REFERENCES rodzaje_produktow;

-------------------DOSTAWA-------------------

CREATE SEQUENCE seq_dostawa START WITH 1;

CREATE OR REPLACE TYPE t_dostawa AS OBJECT(
    id_dostawy          NUMBER,
    kontrakt_ref        REF t_kontrakt,
    czy_wychodzaca      NUMBER(1),
    data_realizacji     DATE,
    faktyczna_ilosc     NUMBER,
    kwota               NUMBER,
    uwagi               VARCHAR2(200),

    CONSTRUCTOR FUNCTION t_dostawa(
        p_kontrakt_ref      REF t_kontrakt,
        p_faktyczna_ilosc   NUMBER
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_dostawa AS
    CONSTRUCTOR FUNCTION t_dostawa(
        p_kontrakt_ref      REF t_kontrakt,
        p_faktyczna_ilosc   NUMBER
    ) RETURN SELF AS RESULT IS
        v_kontrakt t_kontrakt;
    BEGIN
        IF p_kontrakt_ref IS NULL THEN
            RAISE_APPLICATION_ERROR(-20019, 'Dostawa musi być powiązana z kontraktem.');
        END IF;

        SELECT DEREF(p_kontrakt_ref) INTO v_kontrakt FROM DUAL;

        SELF.id_dostawy      := seq_dostawa.NEXTVAL;
        SELF.kontrakt_ref    := p_kontrakt_ref;
        SELF.data_realizacji := SYSDATE;
        SELF.faktyczna_ilosc := p_faktyczna_ilosc;
        SELF.czy_wychodzaca  := v_kontrakt.czy_wychodzacy;

        SELF.kwota := (p_faktyczna_ilosc / 100) * v_kontrakt.cena_za_100_gram;

        IF p_faktyczna_ilosc = v_kontrakt.ilosc_planowa_g THEN
            SELF.uwagi := 'Dostawa zgodna: planowa ilosc (' || v_kontrakt.ilosc_planowa_g || ')';
        ELSIF p_faktyczna_ilosc < v_kontrakt.ilosc_planowa_g THEN
            SELF.uwagi := 'Mniejsza ilosc względem planu (Plan: ' || v_kontrakt.ilosc_planowa_g || ')';
        ELSE
            SELF.uwagi := 'Wieksza ilosc względem planu (Plan: ' || v_kontrakt.ilosc_planowa_g || ')';
        END IF;

        RETURN;
    END;
END;
/

CREATE TABLE dostawy OF t_dostawa(
    CONSTRAINT pk_dostawy PRIMARY KEY (id_dostawy),
    kontrakt_ref SCOPE IS kontrakty NOT NULL
);

ALTER TABLE dostawy 
ADD CONSTRAINT fk_dostawa_kontrakt 
FOREIGN KEY (kontrakt_ref) REFERENCES kontrakty;

-------------------POLE MAGAZYNU-------------------

CREATE SEQUENCE seq_pola START WITH 1;

CREATE OR REPLACE TYPE t_pole_magazynu AS OBJECT(
    id_pola             NUMBER,
    czy_surowiec        NUMBER(1),
    surowiec_ref        REF t_surowiec_mleczarski,
    partia_ref          REF t_partia_produktu,
    ilosc               NUMBER,

    CONSTRUCTOR FUNCTION t_pole_magazynu(
        p_czy_surowiec  NUMBER,
        p_surowiec_ref  REF t_surowiec_mleczarski,
        p_partia_ref    REF t_partia_produktu,
        p_ilosc         NUMBER
    ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY t_pole_magazynu AS
    CONSTRUCTOR FUNCTION t_pole_magazynu(
        p_czy_surowiec  NUMBER,
        p_surowiec_ref  REF t_surowiec_mleczarski,
        p_partia_ref    REF t_partia_produktu,
        p_ilosc         NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        IF p_ilosc <= 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Ilość musi być większa od 0');
        END IF;
        
        SELF.id_pola      := seq_pola.NEXTVAL;
        SELF.ilosc        := p_ilosc;
        SELF.czy_surowiec := p_czy_surowiec;
        SELF.surowiec_ref := NULL;
        SELF.partia_ref   := NULL;

        IF p_czy_surowiec = 1 THEN
            IF p_surowiec_ref IS NULL THEN
                RAISE_APPLICATION_ERROR(-20022, 'Dla surowca należy podać referencję do surowca');
            END IF;
            SELF.surowiec_ref := p_surowiec_ref;
        ELSE
            IF p_partia_ref IS NULL THEN
                RAISE_APPLICATION_ERROR(-20023, 'Należy podać referencję do partii produktu');
            END IF;
            SELF.partia_ref := p_partia_ref;
        END IF;

        RETURN;
    END;
END;
/

CREATE OR REPLACE TYPE t_lista_pol AS TABLE OF t_pole_magazynu;
/

-------------------MAGAZYN-------------------

CREATE OR REPLACE TYPE t_magazyn AS OBJECT(
    pola t_lista_pol,

    MEMBER PROCEDURE wypisz_stan_produktow,
    MEMBER PROCEDURE przyjmij_z_dostawy(p_id_surowca NUMBER, p_ilosc NUMBER),
    MEMBER PROCEDURE usun_zasob(p_id_pola NUMBER, p_ilosc NUMBER),
    MEMBER FUNCTION  sprawdz_stan(p_typ NUMBER, p_id_obiektu NUMBER) RETURN NUMBER,
    MEMBER PROCEDURE przyjmij_z_produkcji(p_id_partii NUMBER, p_ilosc NUMBER)
);
/

create or replace TYPE BODY t_magazyn AS

    MEMBER PROCEDURE wypisz_stan_produktow IS
        v_partia        t_partia_produktu;
        v_rodzaj_p      t_rodzaj_produktu;
        v_surowiec      t_surowiec_mleczarski;
	v_rodzaj_s	t_rodzaj_surowca;
        v_dostawa       t_dostawa;
        v_data_waznosci DATE;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- RAPORT STANU MAGAZYNOWEGO ---');
        IF SELF.pola IS NOT NULL THEN
            FOR i IN 1 .. SELF.pola.COUNT LOOP
                IF SELF.pola.EXISTS(i) THEN
                    DBMS_OUTPUT.PUT('Pole ID: ' || SELF.pola(i).id_pola || ' | Ilość: ' || SELF.pola(i).ilosc || ' | ');

                    IF SELF.pola(i).czy_surowiec = 1 THEN
                        SELECT DEREF(SELF.pola(i).surowiec_ref) INTO v_surowiec FROM DUAL;
                        SELECT DEREF(v_surowiec.rodzaj_ref) INTO v_rodzaj_s FROM DUAL;

                        v_data_waznosci := v_surowiec.data_waznosci;

                        DBMS_OUTPUT.PUT_LINE('Surowiec: ' || v_rodzaj_s.nazwa_surowca || 
                                             ' | Ważny do: ' || TO_CHAR(v_data_waznosci, 'YYYY-MM-DD'));
                    ELSE
                        SELECT DEREF(SELF.pola(i).partia_ref) INTO v_partia FROM DUAL;
                        SELECT DEREF(v_partia.rodzaj_ref) INTO v_rodzaj_p FROM DUAL;

                        DBMS_OUTPUT.PUT_LINE('Produkt: ' || v_rodzaj_p.nazwa_rodzaju || 
                                             ' (Partia nr ' || v_partia.numer_partii || ')' ||
                                             ' | Ważny do: ' || TO_CHAR(v_partia.data_waznosci, 'YYYY-MM-DD'));
                    END IF;
                END IF;
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Magazyn jest pusty.');
        END IF;
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END;

     MEMBER PROCEDURE przyjmij_z_dostawy(p_id_surowca NUMBER, p_ilosc NUMBER) IS
        v_surowiec_ref REF t_surowiec_mleczarski;
        v_znaleziono BOOLEAN := FALSE;
    BEGIN
        BEGIN
            SELECT REF(s) INTO v_surowiec_ref
            FROM surowce_mleczarskie s 
            WHERE id_surowca = p_id_surowca;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20030, 'Nie znaleziono surowca o id: ' || p_id_surowca);
        END;

        IF SELF.pola IS NULL THEN
            SELF.pola := t_lista_pol();
        END IF;

        FOR i IN 1 .. SELF.pola.COUNT LOOP
            IF SELF.pola.EXISTS(i) THEN
                IF SELF.pola(i).czy_surowiec = 1 AND SELF.pola(i).surowiec_ref = v_surowiec_ref THEN
                    SELF.pola(i).ilosc := SELF.pola(i).ilosc + p_ilosc;
                    v_znaleziono := TRUE;
                    EXIT;
                END IF;
            END IF;
        END LOOP;

        IF NOT v_znaleziono THEN
            SELF.pola.EXTEND;
            SELF.pola(SELF.pola.LAST) := t_pole_magazynu(
                p_czy_surowiec => 1,
                p_surowiec_ref => v_surowiec_ref,
                p_partia_ref   => NULL,
                p_ilosc        => p_ilosc
            );
        END IF;
    END;


    MEMBER PROCEDURE usun_zasob(p_id_pola NUMBER, p_ilosc NUMBER) IS
    BEGIN
        IF SELF.pola IS NULL THEN RETURN; END IF;

        FOR i IN 1 .. SELF.pola.COUNT LOOP
            IF SELF.pola.EXISTS(i) AND SELF.pola(i).id_pola = p_id_pola THEN
                IF SELF.pola(i).ilosc > p_ilosc THEN
                    SELF.pola(i).ilosc := SELF.pola(i).ilosc - p_ilosc;
                ELSIF SELF.pola(i).ilosc = p_ilosc THEN
                    SELF.pola.DELETE(i);
                ELSE
                    RAISE_APPLICATION_ERROR(-20026, 'Nie ma wystarczającej ilości towaru na tym polu!');
                END IF;
                RETURN;
            END IF;
        END LOOP;
        RAISE_APPLICATION_ERROR(-20027, 'Nie znaleziono pola o ID: ' || p_id_pola);
    END;

    MEMBER FUNCTION sprawdz_stan(p_typ NUMBER, p_id_obiektu NUMBER) RETURN NUMBER IS
        v_suma       NUMBER := 0;
        v_surowiec   t_surowiec_mleczarski;
        v_partia     t_partia_produktu;
        v_rodzaj_p   t_rodzaj_produktu;
        v_rodzaj_s   t_rodzaj_surowca;
        v_date  DATE;
    BEGIN
        IF SELF.pola IS NULL THEN RETURN 0; END IF;
        v_date := SYSDATE;
        FOR i IN 1 .. SELF.pola.COUNT LOOP
            IF SELF.pola.EXISTS(i) AND SELF.pola(i).czy_surowiec = p_typ THEN

                IF p_typ = 1 THEN
                    SELECT DEREF(SELF.pola(i).surowiec_ref) INTO v_surowiec FROM DUAL;
                    SELECT DEREF(v_surowiec.rodzaj_ref) INTO v_rodzaj_s FROM DUAL;

                    IF v_rodzaj_s.id_rodzaju = p_id_obiektu AND v_surowiec.data_waznosci > v_date THEN
                        v_suma := v_suma + SELF.pola(i).ilosc;
                    END IF;
                ELSE
                    SELECT DEREF(SELF.pola(i).partia_ref) INTO v_partia FROM DUAL;
                    SELECT DEREF(v_partia.rodzaj_ref) INTO v_rodzaj_p FROM DUAL;

                    IF v_rodzaj_p.id_rodzaju = p_id_obiektu AND v_partia.data_waznosci > v_date THEN
                        v_suma := v_suma + SELF.pola(i).ilosc;
                    END IF;
                END IF;

            END IF;
        END LOOP;
        RETURN v_suma;
    END;

    MEMBER PROCEDURE przyjmij_z_produkcji(p_id_partii NUMBER, p_ilosc NUMBER) IS
        v_partia_ref REF t_partia_produktu;
        v_znaleziono BOOLEAN := FALSE;
    BEGIN
        BEGIN
            SELECT REF(p) INTO v_partia_ref 
            FROM partie_produktow p 
            WHERE numer_partii = p_id_partii;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20030, 'Nie znaleziono partii produktu o numerze: ' || p_id_partii);
        END;

        IF SELF.pola IS NULL THEN
            SELF.pola := t_lista_pol();
        END IF;

        FOR i IN 1 .. SELF.pola.COUNT LOOP
            IF SELF.pola.EXISTS(i) THEN
                IF SELF.pola(i).czy_surowiec = 0 AND SELF.pola(i).partia_ref = v_partia_ref THEN
                    SELF.pola(i).ilosc := SELF.pola(i).ilosc + p_ilosc;
                    v_znaleziono := TRUE;
                    EXIT;
                END IF;
            END IF;
        END LOOP;

        IF NOT v_znaleziono THEN
            SELF.pola.EXTEND;
            SELF.pola(SELF.pola.LAST) := t_pole_magazynu(
                p_czy_surowiec => 0,
                p_surowiec_ref => NULL,
                p_partia_ref   => v_partia_ref,
                p_ilosc        => p_ilosc
            );
        END IF;
    END;
END;
/

CREATE TABLE magazyn OF t_magazyn 
NESTED TABLE pola STORE AS tab_pola_magazynowe;

INSERT INTO magazyn VALUES (t_magazyn(t_lista_pol()));
COMMIT;

