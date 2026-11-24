CREATE OR REPLACE PACKAGE BODY IT.PAI_DTM is

-- Private type declarations
    V_SQL VARCHAR2(4000);
    V_NOM VARCHAR2(30);
-- Function and procedure implementations
--Carga tabla temporal Catalgo de Clientes
PROCEDURE PR_CAR_CTUPMMDD
IS
BEGIN
           begin
           delete datamart.ctupmmdd;

           commit;
          exception
            when others then
                 raise_application_error(-20000,'No se puede vaciar ctupmmdd'||sqlerrm);
          end;
          begin
          insert into datamart.ctupmmdd(nu_cta_clte,nu_clte)
          select nu_cta_clte,
                 nu_clte
            from it.iv_ctupmmdd_2;
            commit;
          exception
            when others then
                 raise_application_error(-20000,'Error al cargar ctupmmdd'||sqlerrm);
          end;

EXCEPTION
          WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000,'No se puede cargar tabla CTUPMMDD '||SQLERRM);

END;

--Catalogo de Gestores del Banco.
PROCEDURE PR_GEN_FUUPMMDD
IS

BEGIN
    --Nombre del Archivo.
    V_NOM:='DFUUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
    -- Cabecera
    V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  LPAD(''*'',39,'' '')
           FROM IV_FUUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    -- Detalle
    V_SQL:='SELECT CADENA FROM IV_FUUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N', null, 'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de FUUPMMDD'||sqlerrm);
END;

--Catalogo de Monedas del Banco.
PROCEDURE PR_GEN_MOUPMMDD
IS
BEGIN
    --Nombre del Archivo.
    V_NOM:='DMOUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
    --Cabecera
    v_sql:='SELECT ''0007''||
                   TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                   LPAD(COUNT(*),7,''0'')||
                   LPAD(''*'',28,'' '')
            FROM IV_MOUPMMDD';
     prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
     v_sql:='SELECT CADENA FROM IV_MOUPMMDD';
     prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de MOUPMMDD'||sqlerrm);
END;

--Catalogo de Operadores del Sistema
PROCEDURE PR_GEN_OPUPMMDD
IS
BEGIN
    --Nombre del Archivo.
    V_NOM:='DOPUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
    --Cabecera
    V_SQL:='SELECT ''0007''||
                   TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                   LPAD(COUNT(*),7,''0'')||
                   LPAD(''*'',39,'' '')
            FROM IV_OPUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
    V_SQL:='SELECT CADENA FROM IV_OPUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de OPUPMMDD'||sqlerrm);
END;

--Catalogo de Productos contables del Banco
PROCEDURE PR_GEN_PRUPMMDD
IS
BEGIN
    --Nombre del Archivo.
    V_NOM:='DPRUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
    --Cabecera
     V_SQL:='SELECT ''0007''||
                    TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                    LPAD(COUNT(*),7,''0'')||
                    LPAD(''*'',34,'' '')
             FROM IV_PRUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
    V_SQL:='SELECT CADENA FROM IV_PRUPMMDD';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de PRUPMMDD'||sqlerrm);
END;


--Catalogo de tipos de Transacciones.
PROCEDURE PR_GEN_TTUPMMDD
IS
BEGIN
   --Nombre del Archivo.
    V_NOM:='DTTUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  LPAD(''*'',36,'' '')
           FROM IV_TTUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TTUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de TTUPMMDD'||sqlerrm);
END;


--Catalogo de oficinas del Banco.
PROCEDURE PR_GEN_UOUPMMDD
IS
BEGIN
   --Nombre del Archivo.
    V_NOM:='DUOUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  LPAD(''*'',47,'' '')
           FROM  IV_UOUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM  IV_UOUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de UOUPMMDD'||sqlerrm);
END;

--Archivo de titulares del Banco
PROCEDURE PR_GEN_CTUPMMDD
IS
BEGIN
  --Nombre del Archivo.
  V_NOM:='DCTUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
  --Cabecera
  V_SQL:='SELECT ''0007''||
                 TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                 LPAD(COUNT(*),7,''0'')||
                 LPAD(''*'',162,'' '')
          FROM IV_CTUPMMDD';
  prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
  --DEtalle
  V_SQL:='SELECT CADENA FROM IV_CTUPMMDD';
  prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de CTUPMMDD'||sqlerrm);
END;

--Archivo de Cotitulares del Banco
PROCEDURE PR_GEN_TCUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DTCUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  LPAD(''*'',84,'' '')
           FROM IV_TCUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TCUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de TCUPMMDD'||sqlerrm);
END;

--Archivo de inversiones de Clientes
PROCEDURE PR_GEN_INUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DINUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  pai_dtm.fu_for_montos(sum(im_transaccion))||
                  LPAD(''*'',297,'' '')
           FROM IV_INUPMMDD2';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_INUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de INUPMMDD'||sqlerrm);
END;

--Archivo de Saldos de Cuentas por Clientes
PROCEDURE PR_GEN_SAUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DSAUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  pai_dtm.fu_for_montos(sum(IM_SALDO))||
                  pai_dtm.fu_for_montos(sum(IM_INT_DEVENGA))||
                  LPAD(''*'',127,'' '')
           FROM IV_SAUPMMDD2';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_SAUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de SAUPMMDD'||sqlerrm);
END;

--Archivo de Transacciones de Clientes.
PROCEDURE PR_GEN_TRUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DTRUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  lpad((select count(*) from iv_trupmmdd2 a where a.im_transaccion>=0),7,''0'')||
                  lpad((select count(*) from iv_trupmmdd2 a where a.im_transaccion<0),7,''0'')||
                  (select pai_dtm.fu_for_montos(sum(a.im_transaccion)) from iv_trupmmdd2 a where a.im_transaccion>=0)||
                  (select pai_dtm.fu_for_montos(sum(a.im_transaccion)) from iv_trupmmdd2 a where a.im_transaccion<0)||
                   LPAD(''*'',341,'' '')
           FROM DUAL';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TRUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de TRUPMMDD'||sqlerrm);
END;

--Genera Catalogo de Titularidades
PROCEDURE PR_GEN_TIUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DTIUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'') ||
                  LPAD(''*'',43,'' '')
           FROM IV_TIUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TIUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de TIUPMMDD'||sqlerrm);
END;



--Genera Archivo de Dias Inhabiles del Banco
PROCEDURE PR_GEN_DIUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DDIUP'||TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  ''*''
           FROM IV_DIUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_DIUPMMDD';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de DIUPMMDD'||sqlerrm);
END;


--Genera archivo de perfil de clientes nuevos
PROCEDURE PR_GEN_MPUPMMDD
IS
BEGIN
   --Nombre del Archivo.
   V_NOM:='DMPUP'||TO_CHAR(pag_cal.fu_OBT_fec_actual(1),'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pag_cal.fu_OBT_fec_actual(1),''MM/DD/YYYY'')||
                  LPAD(COUNT(*),7,''0'')||
                  ''*''
           FROM iv_mpupmmdd';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM iv_mpupmmdd';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de MPUPMMDD'||sqlerrm);
END;

--Generar Archivos para DATAMART
PROCEDURE PR_GEN_ARC_DATAMART
IS
BEGIN
        /*a*/  pai_dtm.PR_CAR_CTUPMMDD;
        /*b*/  pai_dtm.PR_ACT_SEG_RIE_CLI_NUEVOS;

        /*1*/  pai_dtm.PR_GEN_CTUPMMDD;
        /*2*/  pai_dtm.PR_GEN_MOUPMMDD;
        /*3*/  pai_dtm.PR_GEN_OPUPMMDD;
        /*4*/  pai_dtm.PR_GEN_PRUPMMDD;
        /*5*/  pai_dtm.PR_GEN_TTUPMMDD;
        /*6*/  pai_dtm.PR_GEN_UOUPMMDD;
        /*7*/  pai_dtm.pr_gen_fuupmmdd;
        /*8*/  pai_dtm.PR_GEN_TCUPMMDD;
        /*9*/  pai_dtm.PR_GEN_INUPMMDD;
       /*10*/  pai_dtm.PR_GEN_SAUPMMDD;
       /*11*/  pai_dtm.PR_GEN_TRUPMMDD;
       /*12*/  pai_dtm.PR_GEN_DIUPMMDD;
       /*13*/  PAI_DTM.PR_GEN_TIUPMMDD;
       /*14*/  PAI_DTM.PR_GEN_MPUPMMDD;

exception
          when others then
               raise_application_error(-20000,'Error al ejecutar Creacion de Archivos para DATAMART'||sqlerrm);

END;



--Carga la tabla de IC_DIA_INHABILES
PROCEDURE PR_INS_DIA_INHABILES
IS
V_FECHA1 DATE;
V_CON NUMBER:=0;

BEGIN
      DELETE IC_DIA_INHABILES;
      select sysdate-365 into V_FECHA1 from dual;
      FOR V_CON IN 1..730 LOOP
           V_FECHA1:=V_FECHA1 +1;
          if to_char(V_FECHA1,'DAY','NLS_DATE_LANGUAGE=SPANISH')LIKE'%SÁBADO%'
             OR to_char(V_FECHA1,'DAY','NLS_DATE_LANGUAGE=SPANISH')LIKE'%DOMINGO%' then
             BEGIN
                  INSERT INTO IC_DIA_INHABILES(FECHA)
                  VALUES(TRUNC(V_FECHA1));
                  COMMIT;
             EXCEPTION
                  WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar Inserciones en IC_DIA_INHABILES'||sqlerrm);
             end;
          end if;
     END LOOP;
     BEGIN
         INSERT INTO IC_DIA_INHABILES(FECHA)
         SELECT A.FECHA FROM BA_FERIADOS A
         WHERE A.COD_OFICINA IS NULL
         AND A.FECHA NOT IN(SELECT B.FECHA FROM IC_DIA_INHABILES B);
         COMMIT;
     EXCEPTION
         WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar Inserciones en IC_DIA_INHABILES de BA_FERIADOS'||sqlerrm);
     END;


END;

--Funcion que obtiene determinadas fechas de la cuenta.
/*P_TIP_FECHA VALORES POSIBLES
1=FECHA DE ULTIMO MOVIMIENTO DE LA CUENTA
2=FECHA DE APERTURA
3=FECHA DE CANCELACION
4=FECHA VENCIMIENTO
*/
FUNCTION FU_OBT_FEC_CUENTAS(P_NRO_CUENTA IN VARCHAR2,
                       P_MODALIDAD IN NUMBER,
                       P_TIP_FECHA NUMBER)

RETURN DATE IS
FECHA DATE;
BEGIN
CASE
WHEN P_TIP_FECHA=1 THEN
     CASE
         WHEN P_MODALIDAD=31 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM AH_CTA_VISTAS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
         WHEN P_MODALIDAD=32 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM AH_CTA_PLAZOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
         WHEN P_MODALIDAD=33 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM AH_CTA_CERTIFICADOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
         WHEN P_MODALIDAD=41 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM CC_CTA_CORRIENTES A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
     END CASE;
WHEN P_TIP_FECHA=2 THEN
     SELECT A.FEC_APERTURA INTO FECHA
     FROM GE_CUENTAS A
     WHERE A.NRO_CUENTA=P_NRO_CUENTA;
     RETURN FECHA;
WHEN P_TIP_FECHA=3 THEN
     SELECT A.FEC_CAM_ESTADO INTO FECHA
     FROM GE_CUENTAS A
     WHERE A.NRO_CUENTA=P_NRO_CUENTA;
     RETURN FECHA;
WHEN P_TIP_FECHA=4 THEN
     CASE
        WHEN P_MODALIDAD=32 THEN
              SELECT A.FEC_VENCIMIENTO INTO FECHA
              FROM AH_CTA_PLAZOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
         WHEN P_MODALIDAD=33 THEN
              SELECT A.FEC_VENCIMIENTO INTO FECHA
              FROM AH_CTA_CERTIFICADOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN FECHA;
     END CASE;
END CASE;

EXCEPTION
         WHEN OTHERS THEN
              Return null;
              raise_application_error(-20000,'CUENTA NRO:'||P_NRO_CUENTA||'Modalidad: '||P_MODALIDAD||' ERROR AL BUSCAR LA FECHA DE ULTIMO MOVIMIENTO'||SQLERRM);
END;


----Funcion que da formato al codigo de los gestores
FUNCTION FU_FOR_COD_GESTOR(P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE)
RETURN VARCHAR2
IS
USUARIO VARCHAR2(10);
BEGIN
        CASE
            WHEN INSTR(P_COD_USUARIO,'F',1)=1 OR (P_COD_USUARIO = 'GESTORCITI')THEN
                 SELECT TO_CHAR(10000+A.COD_OFICINA)INTO USUARIO
                 FROM BA_USUARIOS A
                 WHERE A.COD_USUARIO=P_COD_USUARIO;
            WHEN INSTR((P_COD_USUARIO),'X',1)=1 THEN
                 SELECT SUBSTR(A.COD_USUARIO,4,8)INTO USUARIO
                 FROM BA_USUARIOS A
                 WHERE A.COD_USUARIO=P_COD_USUARIO;
            WHEN INSTR((P_COD_USUARIO),'P',1)=1 THEN
                 SELECT SUBSTR(A.COD_USUARIO,3,8)INTO USUARIO
                 FROM BA_USUARIOS A
                 WHERE A.COD_USUARIO=P_COD_USUARIO;
            ELSE
                 SELECT SUBSTR(A.COD_USUARIO,1,5)INTO USUARIO
                 FROM BA_USUARIOS A
                 WHERE A.COD_USUARIO=P_COD_USUARIO;
       END CASE;
RETURN USUARIO;
EXCEPTION
       WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,'No existe el usuario: '||P_COD_USUARIO||SQLERRM);

END;

--Funcion que trae el estado de la cuenta de un cliente
FUNCTION FU_OBT_EST_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                           P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE)
RETURN CHAR
IS
V_ESTADO CHAR;
V_ACTIVO CHAR;
BEGIN
     SELECT A.ESTADO INTO V_ESTADO
     FROM GE_CUENTAS A
     WHERE A.NRO_CUENTA=P_NRO_CUENTA;
     BEGIN
           SELECT A.ACTIVO INTO V_ACTIVO
           FROM GE_EST_CUENTAS A
           WHERE A.COD_MODALIDAD=P_COD_MODALIDAD
           AND A.ESTADO=V_ESTADO;
           CASE
               WHEN V_ACTIVO='S' THEN
                    RETURN'A';
               ELSE
                    RETURN'C';
           END CASE;
     EXCEPTION
           WHEN OTHERS THEN
                RETURN 'X';
     END;
exception
     when others then
          return 'X' ;

END;

--Funcion que obtiene el grupo economico del cliente
FUNCTION FU_OBT_COD_GRU_ECONOMICO(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
RETURN NUMBER
IS
V_COD_GRUPO NUMBER;

BEGIN
       SELECT A.COD_GRU_ECONOMICO INTO V_COD_GRUPO
       FROM GE_CLIENTES A
       WHERE A.COD_PERSONA=P_COD_PERSONA;
       RETURN V_COD_GRUPO;
EXCEPTION
       WHEN OTHERS THEN
            RETURN null;
END;

--Funcion que obtiene el nombre del grupo economico
FUNCTION FU_OBT_NOM_GRU_ECONOMICO(P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE)
RETURN VARCHAR2
IS
V_NOM_GRUPO VARCHAR2(60);
BEGIN
       SELECT A.DESCRIPCION INTO V_NOM_GRUPO
       FROM GE_GRU_ECONOMICOS A
       WHERE A.COD_GRU_ECONOMICO=P_COD_GRU_ECONOMICO;
       RETURN V_NOM_GRUPO;
EXCEPTION
       WHEN OTHERS THEN
            RETURN NULL;
END;


--funcion que obtiene el nombre del cliente
FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
V_NOM_PERSONA VARCHAR2(120);
BEGIN
       SELECT A.NOM_COMPLETO INTO V_NOM_PERSONA
       FROM BA_PERSONAS A
       WHERE A.COD_PERSONA=P_COD_PERSONA;
       RETURN V_NOM_PERSONA;
EXCEPTION
       WHEN OTHERS THEN
            RETURN 'SN';
END;


--Funcion que obtiene el gestor del cliente.
FUNCTION FU_OBT_GESTOR(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
V_COD_USU_OFICIAL VARCHAR2(10);
BEGIN
       SELECT A.COD_USU_OFICIAL INTO V_COD_USU_OFICIAL
       FROM GE_CLIENTES A
       WHERE A.COD_PERSONA=P_COD_PERSONA;
       RETURN V_COD_USU_OFICIAL;
EXCEPTION
       WHEN OTHERS THEN
            return null;
            RAISE_APPLICATION_ERROR(-20000,'Error al buscar Cliente: '||P_COD_PERSONA||SQLERRM);
END;

--Funcion que obtiene el pais Donde Reside el Cliente.
FUNCTION FU_OBT_PAIS(P_COD_PERSONA IN BA_DIRECCIONES.COD_PERSONA%TYPE)
RETURN NUMBER
IS
V_COD_PAIS NUMBER;
BEGIN
       SELECT A.COD_PAIS INTO V_COD_PAIS
       FROM BA_DIRECCIONES A
       WHERE A.COD_PERSONA=P_COD_PERSONA
       AND A.PRINCIPAL='S';
       RETURN V_COD_PAIS;
EXCEPTION
       WHEN OTHERS THEN
            Return NULL;
            RAISE_APPLICATION_ERROR(-20000,'Error al buscar pais del cliente Nro: '||P_COD_PERSONA||SQLERRM);
END;

--Funcion que obtiene la ciudad Donde Reside el Cliente.
FUNCTION FU_OBT_CIUDAD(P_COD_PERSONA IN BA_DIRECCIONES.COD_PERSONA%TYPE)
RETURN NUMBER
is
V_COD_CIUDAD NUMBER;
BEGIN
       SELECT A.COD_CIUDAD INTO V_COD_CIUDAD
       FROM BA_DIRECCIONES A
       WHERE A.COD_PERSONA=P_COD_PERSONA
       AND A.PRINCIPAL='S';
       RETURN V_COD_CIUDAD;
EXCEPTION
       WHEN OTHERS THEN
            Return NULL;
            RAISE_APPLICATION_ERROR(-20000,'Error al buscar pais del cliente Nro: '||P_COD_PERSONA||SQLERRM);
END;

--Funcion que obtiene la Descripcion del pais.
FUNCTION FU_OBT_NOM_PAIS(P_COD_PAIS IN BA_PAISES.COD_PAIS%TYPE)
RETURN VARCHAR2
IS
V_DESCRIPCION BA_PAISES.DESCRIPCION%TYPE;
BEGIN
--Obtiene el Nombre del País
    select descripcion
    into v_descripcion
    from ba_paises
    where cod_pais = p_cod_pais;

    return v_descripcion;
EXCEPTION
    when no_data_found then
           return NULL;

END;

--Funcion que obtiene la Descripcion de la ciudad.
FUNCTION FU_OBT_NOM_CIUDAD(P_COD_PAIS IN BA_CIUDADES.COD_PAIS%TYPE
                          ,P_COD_CIUDAD IN BA_CIUDADES.COD_CIUDAD%TYPE)
 RETURN VARCHAR2
 IS
 V_DESCRIPCION BA_CIUDADES.DESCRIPCION%TYPE;
 BEGIN
 select descripcion
    into v_descripcion
    from ba_ciudades
    where cod_pais = p_cod_pais
    and cod_ciudad = p_cod_ciudad;

    return v_descripcion;
 EXCEPTION
  when no_data_found then
           return NULL;

 END;


--Funcion que obtiene EL DEPARTAMENTO Donde Reside el Cliente.
FUNCTION FU_OBT_NOM_DEPARTAMENTO(P_COD_PAIS IN BA_PAISES.COD_PAIS%TYPE,
                                 P_COD_CIUDAD IN BA_CIUDADES.COD_CIUDAD%TYPE)
RETURN VARCHAR2
IS
V_NOM_DEPARTAMENTO VARCHAR2(35);
V_COD_DEPARTAMENTO NUMBER(3);
BEGIN
      BEGIN
          SELECT A.COD_DEPARTAMENTO INTO V_COD_DEPARTAMENTO
          FROM BA_CIUDADES A
          WHERE A.COD_CIUDAD=P_COD_CIUDAD
          AND A.COD_PAIS=P_COD_PAIS;
      EXCEPTION
          WHEN OTHERS THEN
          RETURN NULL;
      END;
      BEGIN
          SELECT A.DESCRIPCION INTO V_NOM_DEPARTAMENTO
          FROM BA_DEPARTAMENTOS A
          WHERE V_COD_DEPARTAMENTO=A.COD_DEPARTAMENTO;
          RETURN V_NOM_DEPARTAMENTO;
      EXCEPTION
          WHEN OTHERS THEN
          RETURN NULL;
      END;

EXCEPTION
      WHEN OTHERS THEN
          RETURN NULL;

END;

--Funcion que obtiene la fecha de ingreso del Cliente.
FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
RETURN DATE
IS
V_FEC_INGRESO DATE;
BEGIN
      SELECT A.FEC_INGRESO INTO V_FEC_INGRESO
      FROM GE_CLIENTES A
      WHERE A.COD_PERSONA=P_COD_PERSONA;
      IF ((V_FEC_INGRESO<TO_DATE('01/01/1950','dd/mm/yyyy'))or
         (to_number(to_char(v_fec_ingreso,'yyyy'))>to_number(to_char(sysdate,'yyyy'))))then
           return to_date('01/01/2001','dd/mm/yyyy');
      else
           RETURN V_FEC_INGRESO;
      end if;
EXCEPTION
        WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20000,'Error al buscar fecha del cliente Nro:' ||P_COD_PERSONA||SQLERRM);
END;

--Funcion que da formato a los montos
FUNCTION FU_FOR_MONTOS(P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
RETURN VARCHAR2
IS
V_MONTO VARCHAR2(20);
begin
       IF P_MONTO=0 or P_MONTO IS null THEN
          RETURN '+0000000000000.00';
       END IF;
       select decode(instr(to_char(P_MONTO),'-',1,1),
              1,to_char(P_MONTO,'0000000000000.00'),
              '+'||SUBSTR(to_char(P_MONTO,'0000000000000.00'),2,LENGTH(to_char(P_MONTO,'0000000000000.00'))))into V_MONTO from dual;
        RETURN V_MONTO;

end;

--Funcion que obtiene el capital de la cuenta
FUNCTION FU_OBT_CAP_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                           P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE)
RETURN NUMBER
IS
V_CAPITAL NUMBER(18,2);
BEGIN
     CASE
          WHEN P_COD_MODALIDAD=32 THEN
              SELECT A.CAPITAL INTO V_CAPITAL
                  FROM AH_CTA_PLAZOS A
                  WHERE A.NRO_CUENTA=P_NRO_CUENTA;
                  RETURN  V_CAPITAL;
          WHEN P_COD_MODALIDAD=33 THEN
              SELECT A.CAPITAL INTO V_CAPITAL
              FROM AH_CTA_CERTIFICADOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              RETURN V_CAPITAL;
     END CASE;

EXCEPTION
       WHEN OTHERS THEN

            RAISE_APPLICATION_ERROR(-20000,'Error al buscar capital de la cuenta: '||P_NRO_CUENTA||'Modalidad'||P_COD_MODALIDAD||SQLERRM);

END;

--Funcion que obtiene el  devengado de Ahorro a la Vista
FUNCTION FU_OBT_DEV_AV
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_ULT_CAPITALIZACION IN AH_CTA_VISTAS.FEC_ULT_CAPITALIZACION%TYPE
 )
 RETURN NUMBER
 IS
 BEGIN
        RETURN( pas_bcp.fu_obt_dev_av(p_nro_cuenta,
                                   p_fec_ult_capitalizacion));
 EXCEPTION
        WHEN OTHERS THEN
             RETURN 0;
 END;

--Funcion que obtiene el nombre del gestor
FUNCTION FU_OBT_NOM_GESTOR(P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE)
RETURN VARCHAR2
IS
V_NOM_USUARIO VARCHAR2(60);
BEGIN
       SELECT A.NOMBRE INTO V_NOM_USUARIO
       FROM BA_USUARIOS A
       WHERE A.COD_USUARIO=P_COD_USUARIO;
       RETURN V_NOM_USUARIO;
EXCEPTION
       WHEN OTHERS THEN
            return null;
            RAISE_APPLICATION_ERROR(-20000,'No Existe el usuario: '||P_COD_USUARIO||SQLERRM);
END;


--Procedimiento de segmentacion de Riesgos de Clientes.
PROCEDURE PR_CAL_SEG_RIE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)

IS
V_TIP_PERSONA VARCHAR2(1);
V_RIESGO NUMBER:=0;
V_RESIDENTE VARCHAR2(1);
V_SALDO NUMBER(18,2);
V_PEP VARCHAR2(1);
V_ACTIVIDAD NUMBER(3);
V_SEG_CLIENTE NUMBER(3);
V_COD_TIP_DEUDOR NUMBER(3);
V_COD_GESTOR VARCHAR2(10);
V_COD_OFICINA BA_OFICINAS.COD_OFICINA%TYPE;
V_NOM_PERSONA BA_PERSONAS.NOM_COMPLETO%TYPE;
V_COD_SEC_CONTABLE GE_CLIENTES.COD_SEC_CONTABLE%TYPE;
BEGIN
       -------------------------
       --Asignacion de Riesgos--
       -------------------------


         SELECT A.TIPO,
                B.RESIDENTE,
                A.COD_ACTIVIDAD,
                B.COD_SEG_CLIENTE,
                C.PEP,
                B.COD_TIP_DEUDOR,
                B.COD_USU_OFICIAL,
                B.COD_OFICINA,
                A.NOM_COMPLETO,
                B.COD_SEC_CONTABLE

                INTO
                V_TIP_PERSONA,
                V_RESIDENTE,
                V_ACTIVIDAD,
                V_SEG_CLIENTE,
                V_PEP,
                V_COD_TIP_DEUDOR,
                V_COD_GESTOR,
                V_COD_OFICINA,
                V_NOM_PERSONA,
                V_COD_SEC_CONTABLE

         FROM BA_PERSONAS A,GE_CLIENTES B,CR_INF_FONDOS C
         WHERE A.COD_PERSONA=B.COD_PERSONA
         AND A.COD_PERSONA=C.COD_PERSONA(+)
         AND A.COD_PERSONA=P_COD_PERSONA;

         CASE
         --RIESGO PARA PEP
         WHEN V_PEP='S' THEN
              V_RIESGO:=155;
              pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);

         --No REsidentes
         WHEN V_TIP_PERSONA='F' AND V_RESIDENTE='N' THEN
             V_RIESGO:=156;
             pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
         --CLIENTES SECTOR PUBLICO
         WHEN V_COD_SEC_CONTABLE='P' THEN
              V_RIESGO:= 234;
              pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
         --Funcionarios del banco
         WHEN V_SEG_CLIENTE =6 or V_COD_GESTOR like'%RRHH%'THEN
             V_RIESGO:=301;
             pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);

         --Nominas
         WHEN V_SEG_CLIENTE=26 THEN
             V_RIESGO:=313;
             pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --------------------------------
          --Riesgos por Actividades--
          --------------------------------
          --TABACALERAS
          WHEN V_ACTIVIDAD=313 THEN
               V_RIESGO:=152;
              pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --IMPORTADORAS EXPORTADORAS
          WHEN V_ACTIVIDAD IN(801,406,407,408) THEN
               V_RIESGO:=141;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --HOTELES
          WHEN V_ACTIVIDAD IN(603)THEN
               V_RIESGO:=144;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --Cooperativas
          WHEN V_COD_TIP_DEUDOR=12 THEN
               V_RIESGO:=142;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --fUNDACIONES
          WHEN V_NOM_PERSONA like '%FUNDAC%'or V_NOM_PERSONA like '%FUND.%'or V_NOM_PERSONA like '%FUNDAC.%' then
               V_RIESGO:=154;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --Inmobiliarias
          WHEN V_NOM_PERSONA like '%INMO%' then
               V_RIESGO:=145;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          --Joyerias
          WHEN V_NOM_PERSONA like '%JOYE%' then
               V_RIESGO:=147;
               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
          ELSE
               BEGIN
                     --Agencias de Viajes
                     SELECT 146 INTO V_RIESGO
                     FROM GE_ACTIVIDADES A
                     WHERE A.COD_ACTIVIDAD=V_ACTIVIDAD
                     AND A.COD_ACT_INTERNA='100404';
                     IF V_RIESGO!=0 THEN
                        pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                     END IF;
               EXCEPTION
                     WHEN OTHERS THEN
                        BEGIN
                             --Inmobiliarias
                             SELECT 145 INTO V_RIESGO
                             FROM GE_ACTIVIDADES A
                             WHERE A.COD_ACTIVIDAD=V_ACTIVIDAD
                             AND SUBSTR(A.COD_ACT_INTERNA,1,1)='9'
                             AND ROWNUM=1;
                             IF V_RIESGO!=0 THEN
                                pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                             END IF;
                        EXCEPTION
                             WHEN OTHERS THEN
                                BEGIN

                                     --------------------------------------
                                     --Riesgos por saldos de Cuentas--
                                     --------------------------------------
                                      V_SALDO:=PAI_DTM.FU_OBT_SAL_TOTAL(P_COD_PERSONA);
                                     --Diferenciamos la persona  entre fisica y juridica
                                     IF V_TIP_PERSONA='F' THEN

                                            IF V_SALDO<=50000 THEN
                                               V_RIESGO:=311;
                                               pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                            ELSE
                                               IF V_SALDO>50000 AND V_SALDO<=100000 THEN
                                                  V_RIESGO:=221;
                                                  pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                               ELSE
                                                   V_RIESGO:=231;
                                                  pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                               END IF;
                                            END IF;

                                    ELSE

                                              IF V_SALDO<=50000 THEN
                                                 V_RIESGO:=312;
                                                 pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                              ELSE
                                                 IF V_SALDO>50000 AND V_SALDO<=100000 THEN
                                                    V_RIESGO:=222;
                                                    pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                                 ELSE
                                                     V_RIESGO:=232;
                                                     pai_dtm.PR_ACT_SEG_RIE_CLIENTE(P_cod_persona,V_riesgo);
                                                 END IF;
                                              END IF;
                                     END IF;
                                 END;
                        END;
               END;
            END CASE;



EXCEPTION
       WHEN OTHERS THEN
            rAISE_APPLICATION_ERROR(-20000,'Error al asignar riesgo de cliente: '||P_COD_PERSONA||sqlerrm);

END;


--Funcion que obtiene el saldo de la cuenta en DOLARES.
FUNCTION FU_OBT_SAL_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
RETURN NUMBER
IS
V_SAL_PROMEDIO ge_cuentas.sal_promedio%type;
V_SALDO ge_cuentas.sal_promedio%type;
V_COD_MONEDA VARCHAR2(3);
V_COT_USD NUMBER:=fug_obt_cotizacion('USD');
V_COT_EUR NUMBER:=fug_obt_cotizacion('EUR');
BEGIN
       SELECT A.COD_MONEDA,A.SAL_PROMEDIO INTO V_COD_MONEDA,V_SAL_PROMEDIO
       FROM GE_CUENTAS A
       WHERE A.NRO_CUENTA=P_NRO_CUENTA;
       CASE
       WHEN V_COD_MONEDA='USD' THEN
            V_SALDO:=V_SAL_PROMEDIO;
       WHEN V_COD_MONEDA='GS' THEN
            V_SALDO:=V_SAL_PROMEDIO/V_COT_USD;
       WHEN V_COD_MONEDA='EUR' THEN
            V_SALDO:=(V_SAL_PROMEDIO*V_COT_EUR)/V_COT_USD;
       END CASE;
      RETURN V_SALDO;

EXCEPTION
       WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,'NO existe Cuenta Nro.: '||P_NRO_CUENTA||SQLERRM);
END;

--Procedimiento que actualiza la tabla ba_par_dat_adicionales
Procedure PR_ACT_SEG_RIE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_RIESGO in number)
is
v_existe varchar2(1):=null;
BEGIN
        begin
        select 'S' into v_existe from dual
        where exists (select 1 from ba_per_dat_adicionales a
                           where a.cod_persona=P_COD_PERSONA
                           and a.parametro='DTM_RIESGO');
        EXCEPTION

                   WHEN OTHERS THEN
                   begin
                         insert into ba_per_dat_adicionales(cod_persona,parametro,val_parametro)
                         values(P_cod_persona,'DTM_RIESGO',P_RIESGO) ;
                         commit;
                    exception
                              when others then
                                   raise_application_error(-20000,'No se puede realizar la insercion: '||P_cod_persona||sqlerrm);
                    end;
        END;

if v_existe='S' then
        begin
             update ba_per_dat_adicionales a
             set a.val_parametro= P_RIESGO
             where a.cod_persona=P_COD_PERSONA
             and a.parametro='DTM_RIESGO';
             commit;
        exception

                  when others then
                       raise_application_error(-20000,'No se puede realizar la insercion: '||P_cod_persona||sqlerrm);
        end;


end if;
end;

--Funcion que obtiene el segmento de riesgo de ba_per_dat_adicionales
FUNCTION FU_OBT_SEG_RIE_CLIENTE(p_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
v_riesgo varchar2(20);
BEGIN
       select a.val_parametro into v_riesgo from ba_per_dat_adicionales a
       where a.cod_persona=P_COD_PERSONA
             and a.parametro='DTM_RIESGO';
        return v_riesgo;

EXCEPTION
       WHEN OTHERS THEN
            return null;
            RAISE_APPLICATION_ERROR(-20000,'No existe cliente con segmento de riesgo: '||p_COD_PERSONA||sqlerrm);

END;

--Funcion que obtiene el saldo consolidado de las cuentas del cliente
FUNCTION FU_OBT_SAL_TOTAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN NUMBER
IS
V_SAL_TOTAL GE_CUENTAS.SAL_PROMEDIO%TYPE;
BEGIN
            select sum(pai_dtm.FU_OBT_SAL_CUENTA(a.nro_cuenta)) into V_SAL_TOTAL
                  from ge_cta_clientes a,
                       ge_cuentas b
                  where a.nro_cuenta=b.nro_cuenta
                  and a.cod_persona=P_COD_PERSONA
                  and a.relacion='P'
                  and  a.cod_modalidad in(31,32,33,41)
                  and b.estado not in ('A','X','T','P')
                  and ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='A')or
                      ((pai_dtm_t.fu_obt_est_cuenta(A.NRO_CUENTA,A.COD_MODALIDAD)='C')and
                      ((pai_dtm_t.fu_obt_fec_cuentas(A.NRO_CUENTA,null,3))=pai_dtm_v.FU_OBT_fec_actual(3))))
                  group by a.cod_persona;
             RETURN NVL(V_SAL_TOTAL,0);
EXCEPTION
       WHEN OTHERS THEN
             RETURN NULL;
             RAISE_APPLICATION_ERROR(-20000,'Error al buscar saldo total Persona Nro: '||P_COD_PERSONA||sqlerrm);

END;

--Procedimiento para asignar riesgo a clientes que no poseen
PROCEDURE PR_ACT_SEG_RIE_CLI_NUEVOS
IS

cursor tmp_cur is
      select distinct trim(a.nu_clte) nu_clte from datamart.ctupmmdd a
      minus
      select trim(z.cod_persona) from ba_per_dat_adicionales z
                        where z.parametro='DTM_RIESGO';

begin
for x in tmp_cur loop

   pai_dtm.PR_CAL_SEG_RIE_CLIENTE(x.nu_clte);

end loop;

EXCEPTION
          WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar procedimiento de actualizacion'||SQLERRM);
END;

--Funcion que obtiene cliente frecuente SI/NO
FUNCTION FU_OBT_ES_CLI_FRECUENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
V_CLI_FRECUENTE VARCHAR2(2);
BEGIN
       SELECT A.CLI_FRECUENTE INTO V_CLI_FRECUENTE
       FROM CR_INF_FONDOS A
       WHERE A.COD_PERSONA=P_COD_PERSONA;
       RETURN V_CLI_FRECUENTE;
EXCEPTION
       when no_data_found then
       RETURN NULL;
end;

--Procedimiento para asignar riesgo a clientes no titulares que no poseen
PROCEDURE PR_ACT_SEG_RIE_CLI_COT_NUEVOS
IS

cursor tmp_cur is
      select b.cod_persona nu_clte
      from ge_cta_clientes a,
                ge_clientes b
      where a.cod_persona=b.cod_persona
        and a.relacion!='P'
        and exists(select 1 from datamart.ctupmmdd x
                            where trim(x.nu_cta_clte)=a.nro_cuenta)
        and not exists(select 1 from ba_per_dat_adicionales c
                                where c.parametro='DTM_RIESGO'
                                  and c.cod_persona=b.cod_persona);

begin
for x in tmp_cur loop

   pai_dtm.PR_CAL_SEG_RIE_CLIENTE(x.nu_clte);

end loop;

EXCEPTION
          WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar procedimiento de actualizacion'||SQLERRM);
END;

--Funcion que obtiene el tipo de cliente
FUNCTION FU_OBT_TIP_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE default null,
                            P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL)
RETURN varchar2
IS
v_tip_cliente varchar2(35);
v_cod_paquete number(3);
v_cod_seg_cliente ge_clientes.cod_seg_cliente%type;
BEGIN
     begin
     select a.cod_paquete into v_cod_paquete from ge_paq_cuentas a
     where a.nro_cuenta=P_NRO_CUENTA;
     if v_cod_paquete is not null then
        select b.descripcion into v_tip_cliente from ge_paquetes b
        where b.cod_paquete=v_cod_paquete;
        RETURN v_tip_cliente;
     end if;
     exception
         when others then
         begin
           select c.cod_seg_cliente
             into v_cod_seg_cliente
             from ge_clientes c
            where c.cod_persona = P_COD_PERSONA;
           if v_cod_seg_cliente is not null then
             select c.descripcion
               into v_tip_cliente
               from ge_seg_clientes c
              where c.cod_seg_cliente = v_cod_seg_cliente;
              return v_tip_cliente;
           else
             return null;
           end if;
         exception
           when others then
             return null;
         end;
     end;



END;

--Funcion que determina si una cuenta posee o no chequera
FUNCTION FU_OBT_CAN_CHEQUERAS(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL)
RETURN NUMBER
IS
V_CANTIDAD NUMBER;
BEGIN
select count(*) INTO V_CANTIDAD from cc_chequeras a
where a.nro_cuenta=P_NRO_CUENTA
and a.estado ='E';
RETURN V_CANTIDAD;
EXCEPTION
WHEN OTHERS THEN
RETURN NULL;
END;


end PAI_DTM;
/

