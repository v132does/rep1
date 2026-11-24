create or replace package body it.PAI_DTM_T is

  -- Private type declarations
  
  
  -- Private constant declarations
 

  -- Private variable declarations
  

  -- Function and procedure implementations
  -- Public function and procedure declarations
--  function <FunctionName>(<Parameter> <Datatype>) return <Datatype>;
-- Private type declarations
    V_SQL VARCHAR2(4000);
    V_NOM VARCHAR2(30);
  /*  V_SQL_2 varchar2(5000);*/
-- Function and procedure implementations
function fu_obt_fecha 
return date
is
p_fecha_g date:=to_date('03/05/2010','dd/mm/yyyy');
begin
return p_fecha_g;
end;

PROCEDURE PR_CAR_CTUPMMDD
IS
BEGIN
          NULL;
          /*begin
           delete datamart.dtm_ctupmmdd;
           commit;
          exception
            when others then 
                 raise_application_error(-20000,'No se puede vaciar ctupmmdd'||sqlerrm);
          end;*/
          /*begin
          insert into dtm_ctupmmdd(cd_agencia,
                                     nu_cta_ser,
                                     nu_cta,
                                     nu_parent_num,
                                     sn_parent_num)
          select cd_agencia,
                   trim(nu_cta_ser),
                   nu_cta,
                   nu_parent_num,
                   sn_parent_num
            from iv_ctupmmdd_t_2;
            commit;
          exception
            when others then
                 raise_application_error(-20000,'Error al cargar ctupmmdd'||sqlerrm);
          end; */               
EXCEPTION
          WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar PR_CAR_CTUPMMDD'||sqlerrm);

END;
       
--Catalogo de Gestores del Banco.
PROCEDURE PR_GEN_FUUPMMDD 
IS

BEGIN
    --Nombre del Archivo.
    V_NOM:='DFUUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
    -- Cabecera
    V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',32,'' '')
           FROM IV_FUUPMMDD_V';
   /* execute immediate V_SQL into V_SQL_2 ;
    dbms_output.put_line(V_SQL_2);
    */
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    -- Detalle
    V_SQL:='SELECT CADENA FROM IV_FUUPMMDD_V';
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
    V_NOM:='DMOUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
    --Cabecera
    v_sql:='SELECT ''0007''||
                   TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                   LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',1,'' '')  
            FROM IV_MOUPMMDD_V';
     prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
     v_sql:='SELECT CADENA FROM IV_MOUPMMDD_V';
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
    V_NOM:='DOPUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
    --Cabecera
    V_SQL:='SELECT ''0007''||
                   TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                   LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',29,'' '') 
            FROM IV_OPUPMMDD_V';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
    V_SQL:='SELECT CADENA FROM IV_OPUPMMDD_V';
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
    V_NOM:='DPRUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
    --Cabecera
     V_SQL:='SELECT ''0007''||
                    TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                    LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',27,'' '') 
             FROM IV_PRUPMMDD_V';
    prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
    --Detalle
    V_SQL:='SELECT CADENA FROM IV_PRUPMMDD_V';
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
    V_NOM:='DTTUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',36,'' '') 
           FROM IV_TTUPMMDD_V';       
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TTUPMMDD_V';       
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
    V_NOM:='DUOUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',37,'' '') 
           FROM  IV_UOUPMMDD_V';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM  IV_UOUPMMDD_V';
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
  V_NOM:='DCTUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
  --Cabecera
  V_SQL:='SELECT ''0007''||
                 TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                 LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',153,'' '') 
          FROM IV_CTUPMMDD_T';
  prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
  --DEtalle
  V_SQL:='SELECT CADENA FROM IV_CTUPMMDD_T';
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
   V_NOM:='DTCUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',84,'' '') 
           FROM IV_TCUPMMDD_T';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TCUPMMDD_T';
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
   V_NOM:='DINUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  pai_dtm.fu_for_montos(sum(im_transaccion))||
                  lpad(''*'',301,'' '')
           FROM IV_INUPMMDD2_T';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_INUPMMDD_T';
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
   V_NOM:='DSAUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  pai_dtm.fu_for_montos(sum(IM_SALDO))||
                  pai_dtm.fu_for_montos(sum(im_interes_devengado))||
                  lpad(''*'',127,'' '')
           FROM IV_SAUPMMDD2_T';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_SAUPMMDD_T';
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
   V_NOM:='DTRUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')||
                  lpad((select count(*) from iv_trupmmdd2_t a where a.im_transaccion>=0),7,''0'')||
                  lpad((select count(*) from iv_trupmmdd2_t a where a.im_transaccion<0),7,''0'')||
                  (select pai_dtm.fu_for_montos(sum(a.im_transaccion)) from iv_trupmmdd2_t a where a.im_transaccion>=0)||
                  (select pai_dtm.fu_for_montos(sum(a.im_transaccion)) from iv_trupmmdd2_t a where a.im_transaccion<0)||
                  lpad(''*'',302,'' '')  
           FROM DUAL';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TRUPMMDD_t';
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
   V_NOM:='DTIUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  lpad(''*'',27,'' '') 
           FROM IV_TIUPMMDD_V';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_TIUPMMDD_V';
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
   V_NOM:='DDIUP'||TO_CHAR(pai_dtm_t.fu_obt_fecha,'MMDD')||'.TXT';
   --Cabecera
   V_SQL:='SELECT ''0007''||
                  TO_CHAR(pai_dtm_t.fu_obt_fecha,''MM/DD/YYYY'')|| 
                  LPAD(COUNT(*),7,''0'')||
                  ''*'' 
           FROM IV_DIUPMMDD_V';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N');
   --Detalle
   V_SQL:='SELECT CADENA FROM IV_DIUPMMDD_V';
   prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion de DIUPMMDD'||sqlerrm);
END;
--Generar Archivos para DATAMART
PROCEDURE PR_GEN_ARC_DATAMART
IS
BEGIN
        
        /*0*/  pai_dtm_t.PR_CAR_CTUPMMDD;
        /*1*/  pai_dtm_t.pr_gen_fuupmmdd;
        /*2*/  pai_dtm_t.PR_GEN_MOUPMMDD;
        /*3*/  pai_dtm_t.PR_GEN_OPUPMMDD;
        /*4*/  pai_dtm_t.PR_GEN_PRUPMMDD;
        /*5*/  pai_dtm_t.PR_GEN_TTUPMMDD;
        /*6*/  pai_dtm_t.PR_GEN_UOUPMMDD;
        /*7*/  pai_dtm_t.PR_GEN_CTUPMMDD;
        /*8*/  pai_dtm_t.PR_GEN_TCUPMMDD;
        /*9*/  pai_dtm_t.PR_GEN_INUPMMDD;
       /*10*/  pai_dtm_t.PR_GEN_SAUPMMDD;
       /*11*/  pai_dtm_t.PR_GEN_TRUPMMDD;
       /*12*/  pai_dtm_t.PR_GEN_DIUPMMDD;
       /*13*/  PAI_DTM_t.PR_GEN_TIUPMMDD;
                
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
         SELECT DISTINCT A.FECHA FROM BA_FERIADOS A
         WHERE A.FECHA NOT IN(SELECT B.FECHA FROM IC_DIA_INHABILES B);
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
               CASE
                    WHEN FECHA>=PAI_DTM_T.fu_obt_fecha THEN
                         RETURN TO_DATE('01/01/2001','DD/MM/YYYY');
                    ELSE
                         RETURN FECHA;
              END CASE;
         WHEN P_MODALIDAD=32 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM AH_CTA_PLAZOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
               CASE
                    WHEN FECHA>=PAI_DTM_T.fu_obt_fecha THEN
                        RETURN TO_DATE('01/01/2001','DD/MM/YYYY');
                    ELSE
                         RETURN FECHA;
              END CASE;
         WHEN P_MODALIDAD=33 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM AH_CTA_CERTIFICADOS A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
               CASE
                    WHEN FECHA>=PAI_DTM_T.fu_obt_fecha THEN
                        RETURN TO_DATE('01/01/2001','DD/MM/YYYY');
                    ELSE
                         RETURN FECHA;
              END CASE;
         WHEN P_MODALIDAD=41 THEN
              SELECT A.FEC_ULT_MOVIMIENTO INTO FECHA
              FROM CC_CTA_CORRIENTES A
              WHERE A.NRO_CUENTA=P_NRO_CUENTA;
              CASE
                    WHEN FECHA>=PAI_DTM_T.fu_obt_fecha THEN
                         RETURN TO_DATE('01/01/2001','DD/MM/YYYY');
                    ELSE
                         RETURN FECHA;
              END CASE;
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
            WHEN INSTR(P_COD_USUARIO,'F',1)=1 THEN
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
            Return null;
            RAISE_APPLICATION_ERROR(-20000,'Error al buscar pais del cliente Nro: '||P_COD_PERSONA||SQLERRM);
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
             return to_date('01/01/2001','dd/mm/yyyy'); 
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
            RAISE_APPLICATION_ERROR(-20000,'No Existe el usuario: '||P_COD_USUARIO||SQLERRM);
END;


--Funcion de segmentacion de Riesgos de Clientes.
FUNCTION FU_OBT_SEG_RIE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
RETURN NUMBER
IS
V_TIP_PERSONA VARCHAR2(1);
V_RIESGO NUMBER:=0;
V_RESIDENTE VARCHAR2(1);
V_SALDO NUMBER(18,2);
V_PEP VARCHAR2(1); 
V_ACTIVIDAD NUMBER(3);
V_SEG_CLIENTE NUMBER(3);
V_COD_TIP_DEUDOR NUMBER(3);
BEGIN
       -------------------------
       --Asignacion de Riesgos--
       -------------------------
       begin 
         SELECT A.TIPO,
                B.RESIDENTE,
                A.COD_ACTIVIDAD,
                B.COD_SEG_CLIENTE,
                C.PEP,
                B.COD_TIP_DEUDOR 
                INTO 
                V_TIP_PERSONA,
                V_RESIDENTE,
                V_ACTIVIDAD,
                V_SEG_CLIENTE,
                V_PEP,
                V_COD_TIP_DEUDOR
                
         FROM BA_PERSONAS A,GE_CLIENTES B,CR_INF_FONDOS C
         WHERE A.COD_PERSONA=B.COD_PERSONA
         AND A.COD_PERSONA=C.COD_PERSONA(+)
         AND A.COD_PERSONA=P_COD_PERSONA;
         
         CASE
         --RIESGO PARA PEP
         WHEN V_PEP='S' THEN
              V_RIESGO:=155;
              RETURN V_RIESGO;
         --No REsidentes
         WHEN V_TIP_PERSONA='F' AND V_RESIDENTE='N' THEN
             V_RIESGO:=156;
             RETURN V_RIESGO;
         --Funcionarios del banco
         WHEN V_SEG_CLIENTE =6 THEN
            V_RIESGO:=301;
            RETURN V_RIESGO;
         --Nominas
         WHEN V_SEG_CLIENTE=26 THEN
             V_RIESGO:=313;
             RETURN V_RIESGO;
          -------------------------------- 
          --Riesgos por Actividades--
          --------------------------------
          --TABACALERAS 
          WHEN V_ACTIVIDAD=313 THEN
               V_RIESGO:=152;
               RETURN V_RIESGO;
          --IMPORTADORAS EXPORTADORAS
          WHEN V_ACTIVIDAD IN(801,406,407,408) THEN
               V_RIESGO:=141;
               RETURN V_RIESGO;
          --HOTELES
          WHEN V_ACTIVIDAD IN(603)THEN
               V_RIESGO:=144;
               RETURN V_RIESGO;
          --Cooperativas
          WHEN V_COD_TIP_DEUDOR=12 THEN
               V_RIESGO:=142;
               RETURN V_RIESGO;
          ELSE 
               BEGIN
                     --Agencias de Viajes
                     SELECT 146 INTO V_RIESGO    
                     FROM GE_ACTIVIDADES A
                     WHERE A.COD_ACTIVIDAD=V_ACTIVIDAD
                     AND A.COD_ACT_INTERNA='100404';
                     IF V_RIESGO!=0 THEN
                        RETURN V_RIESGO;
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
                                RETURN V_RIESGO;
                             END IF;
                        EXCEPTION
                             WHEN OTHERS THEN
                                BEGIN 
                                     --------------------------------------
                                     --Riesgos por saldos de Cuentas--
                                     --------------------------------------
                                     --Diferenciamos la persona  entre fisica y juridica
                                     IF V_TIP_PERSONA='F' THEN
                                            V_SALDO:=PAI_DTM.FU_OBT_SAL_CUENTA(P_NRO_CUENTA);
                                            IF V_SALDO<=50000 THEN
                                               V_RIESGO:=311;
                                               RETURN V_RIESGO;
                                            ELSE 
                                               IF V_SALDO>50000 AND V_SALDO<=100000 THEN
                                                  V_RIESGO:=221;
                                                  RETURN V_RIESGO;
                                               ELSE 
                                                   V_RIESGO:=231;
                                                   RETURN V_RIESGO;
                                               END IF;
                                            END IF;          
                                                   
                                    ELSE
                                         V_SALDO:=PAI_DTM.FU_OBT_SAL_CUENTA(P_NRO_CUENTA);
                                              IF V_SALDO<=50000 THEN
                                                 V_RIESGO:=312;
                                                 RETURN V_RIESGO;
                                              ELSE 
                                                 IF V_SALDO>50000 AND V_SALDO<=100000 THEN
                                                    V_RIESGO:=222;
                                                    RETURN V_RIESGO;
                                                 ELSE 
                                                     V_RIESGO:=232;
                                                     RETURN V_RIESGO;
                                                 END IF;
                                              END IF;          
                                     END IF;   
                                 END;  
                        END;
               END;          
            END CASE;
        exception
            when others then
                 return null;
        end;    
      
       
EXCEPTION
       WHEN OTHERS THEN 
            rAISE_APPLICATION_ERROR(-20000,'Error al asignar riesgo de cliente: '||P_COD_PERSONA||sqlerrm);

END;


--Funcion que obtiene el saldo de la cuenta en DOLARES.
FUNCTION FU_OBT_SAL_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
RETURN NUMBER
IS
V_SAL_PROMEDIO NUMBER(18,2);
V_COD_MONEDA VARCHAR2(3);
v_fecha date:=to_date(sysdate,'dd/mm/yyyy');
BEGIN
       SELECT A.COD_MONEDA,A.SAL_PROMEDIO INTO V_COD_MONEDA,V_SAL_PROMEDIO
       FROM GE_CUENTAS A
       WHERE A.NRO_CUENTA=P_NRO_CUENTA;
       CASE 
       WHEN V_COD_MONEDA='USD' THEN
            V_SAL_PROMEDIO:=V_SAL_PROMEDIO;
       WHEN V_COD_MONEDA='GS' THEN   
            V_SAL_PROMEDIO:=V_SAL_PROMEDIO/fug_obt_cotizacion('USD',v_fecha);
       WHEN V_COD_MONEDA='EUR' THEN      
            V_SAL_PROMEDIO:=(V_SAL_PROMEDIO*fug_obt_cotizacion('EUR',v_fecha))/fug_obt_cotizacion('USD',v_fecha);
       END CASE;
      RETURN V_SAL_PROMEDIO;

EXCEPTION
       WHEN OTHERS THEN 
            RAISE_APPLICATION_ERROR(-20000,'NO existe Cuenta Nro.: '||P_NRO_CUENTA||SQLERRM);
END;

--Funcion que obtiene el tipo de persona
FUNCTION FU_OBT_TIP_PERSONA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
V_TIP_PERSONA VARCHAR2(1);
V_COD_TIP_PERSONA VARCHAR2(3);
BEGIN
       select A.TIPO INTO V_TIP_PERSONA
       FROM BA_PERSONAS A
       WHERE A.COD_PERSONA=P_COD_PERSONA;
       case
       when V_TIP_PERSONA='J' THEN
          V_COD_TIP_PERSONA:='01';
          RETURN V_COD_TIP_PERSONA;
       when V_TIP_PERSONA='F' then
          BEGIN
          SELECT '03'INTO V_COD_TIP_PERSONA
          FROM BA_VINCULOS A
          WHERE A.COD_PERSONA=P_COD_PERSONA
          AND A.TIPO='E';
          return v_cod_tip_persona;
          EXCEPTION
              WHEN OTHERS THEN
              SELECT '02'INTO V_COD_TIP_PERSONA
              FROM DUAL;
              RETURN V_COD_TIP_PERSONA;
          END;
        end case;
EXCEPTION
       WHEN OTHERS THEN 
            RETURN '01';
            RAISE_APPLICATION_ERROR(-20000,'Error al buscar tipo de persona de:'||P_COD_PERSONA||sqlerrm);
END;

--Funcion de conversion de cuenta del sistema IT->AS
FUNCTION FU_OBT_NRO_CTA_ANTERIOR(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE)
RETURN VARCHAR2
is
v_nro_cta_anterior varchar2(18);
v_cod_oficina varchar2(2);
v_cod_producto varchar2(6);
v_cod_ant_producto varchar2(6);
v_nro_subcuenta varchar2(6);
v_lon_cuenta number;
v_cod_persona varchar2(10);
begin
v_lon_cuenta:=length(p_nro_cuenta);
case v_lon_cuenta
     when 10 then
          v_cod_oficina:=substr(p_nro_cuenta,1,2);
          v_cod_producto:=substr(p_nro_cuenta,3,2);
          v_nro_subcuenta:=substr(p_nro_cuenta,5,length(p_nro_cuenta));
     else
          v_cod_oficina:='0'||substr(p_nro_cuenta,1,1);
          v_cod_producto:=substr(p_nro_cuenta,2,2);
          v_nro_subcuenta:=substr(p_nro_cuenta,4,length(p_nro_cuenta));
end case;     
case trim(P_COD_MONEDA)
when 'GS' then
     case v_cod_producto
          when '01'then
               v_cod_ant_producto:='210100';
          when '02'then
               v_cod_ant_producto:='210500';
          when '03'then
               v_cod_ant_producto:='211500';
               begin
                   select a.cod_persona into v_cod_persona from ge_cta_clientes a
                   where a.nro_cuenta=P_NRO_CUENTA 
                   and a.relacion='P';
                   v_nro_subcuenta:=lpad(v_cod_persona,6,'0');
               exception
                when others then
                     raise_application_error(-20000,'Error no se encuentra cliente'||sqlerrm);
               end;              
     end case;          
else
    case v_cod_producto
          when '01'then
               v_cod_ant_producto:='215000';
          when '02'then
               v_cod_ant_producto:='215500';
          when '03'then
               v_cod_ant_producto:='216000';
               begin
                   select a.cod_persona into v_cod_persona from ge_cta_clientes a
                   where a.nro_cuenta=P_NRO_CUENTA 
                   and a.relacion='P';
                   v_nro_subcuenta:=lpad(v_cod_persona,6,'0');
               exception
                when others then
                     raise_application_error(-20000,'Error no se encuentra cliente'||sqlerrm);
               end;              
                   
    end case;                           
end case;
v_nro_cta_anterior:=v_cod_oficina||'/'||v_cod_ant_producto||'/'||v_nro_subcuenta;
return v_nro_cta_anterior;
exception
       when others then
            return P_NRO_CUENTA;
            raise_application_error(-20000,'Error al convertir cuenta: '||P_NRO_CUENTA||sqlerrm);
end;

--Funcion de conversion de cuenta del sistema AS->IT
FUNCTION FU_OBT_NRO_CTA_IT(P_NRO_CUENTA IN varchar2,
                           P_COD_PERSONA in varchar2)
RETURN VARCHAR2
is
v_nro_cta_it varchar2(15);
v_cod_oficina varchar2(2);
v_cod_producto varchar2(2);
v_cod_ant_producto varchar2(7);
v_nro_subcuenta varchar2(6):='1';
v_cod_ofi_cta varchar2(2);    

begin
v_cod_oficina:=substr(p_nro_cuenta,1,2);
v_cod_ant_producto:=substr(p_nro_cuenta,4,6);
--v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
case v_cod_ant_producto
         when '210100' then
              v_cod_producto:='01';
              v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
         when '210500' then
              v_cod_producto:='02';
              v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
         when '211500' then
              v_cod_producto:='03';
              v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
         when '215000' then
              v_cod_producto:='01';
              v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
         when '215500' then
              v_cod_producto:='02';
              v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
         when '216000' then
               v_cod_producto:='03';     
              begin
              declare 
              cursor cur_cda is
                     select c.nro_cuenta,c.cod_modalidad,c.cod_oficina,c.cod_moneda,c.nro_certificado from ge_cta_clientes a 
                     inner join ge_cuentas b on(a.nro_cuenta=b.nro_cuenta)
                     inner join ah_cta_certificados c on (c.nro_cuenta=a.nro_cuenta)
                     where a.cod_modalidad =33
                     and c.cod_moneda='GS'
                     and a.cod_persona=p_cod_persona;
                     
                     
                     begin
                           for x in cur_cda loop
                               
                               v_cod_ofi_cta:=substr(x.nro_cuenta,1,2);
                               
                               if v_cod_ofi_cta=v_cod_oficina then
                                  v_nro_subcuenta:=substr(x.nro_cuenta,5,length(x.nro_cuenta));
                                  exit; 
                              /* else                           
                                  v_cod_oficina:=v_cod_ofi_cta;
                                  v_nro_subcuenta:=substr(x.nro_cuenta,5,length(x.nro_cuenta));   
                                  exit;*/
                               end if;
                           end loop;
                     exception
                           when others then
                                raise_application_error(-20000,'Error al ejecutar');      
                           
                          
                     end;
              end;
              when '216500' then
              v_cod_producto:='03';     
              begin
              declare 
              cursor cur_cda is
                     select c.nro_cuenta,c.cod_modalidad,c.cod_oficina,c.cod_moneda,c.nro_certificado from ge_cta_clientes a 
                     inner join ge_cuentas b on(a.nro_cuenta=b.nro_cuenta)
                     inner join ah_cta_certificados c on (c.nro_cuenta=a.nro_cuenta)
                     where a.cod_modalidad =33 
                     and c.cod_moneda='USD'
                     and a.cod_persona=p_cod_persona;
                     begin
                           for x in cur_cda loop
                               v_cod_ofi_cta:=substr(x.nro_cuenta,1,2);
                               If v_cod_ofi_cta=v_cod_oficina then
                                  v_nro_subcuenta:=substr(x.nro_cuenta,5,length(x.nro_cuenta));
                                  exit;
                               /*else                           
                                  v_cod_oficina:=v_cod_ofi_cta;
                                  v_nro_subcuenta:=substr(x.nro_cuenta,5,length(x.nro_cuenta));   
                                  exit;*/
                               end if;
                           end loop;
                     exception
                           when others then
                                raise_application_error(-20000,'Error al ejecutar');      
                           
                          
                     end;
              end;
             
              else
                     return null;
              
              
end case; 
if v_nro_subcuenta='1' then
                 v_nro_subcuenta:=substr(p_nro_cuenta,11,6);
              end if;         
v_nro_cta_it:=v_cod_oficina||v_cod_producto||v_nro_subcuenta;
return v_nro_cta_it;
exception
       when others then
            return P_NRO_CUENTA;
            raise_application_error(-20000,'Error al convertir cuenta: '||P_NRO_CUENTA||sqlerrm);
end;

--Funcion que obtiene la fecha del modulo
FUNCTION FU_OBT_fec_actual(P_COD_MODULO in ge_cuentas.cod_modulo%type)
RETURN date
is

fecha date;
begin
       select a.fec_actual into fecha from ge_calendarios a
       where a.cod_modulo=P_COD_MODULO;
       return fecha;
exception
       when others then
            raise_application_error(-20000,'No se encontro la fecha del modulo:'||p_cod_modulo||sqlerrm);
end;

--Funcion que obtiene el numero de cuanta a la cual afecto una 518
Function FU_obt_nro_cta_tmp(P_fecha in ge_movimientos.fecha%type,
                            P_hora in ge_movimientos.hora%type,
                            P_nro_documento in ge_movimientos.nro_documento%type)
return varchar2
is
v_nro_cuenta varchar2(10);
begin
       select a.nro_cuenta into v_nro_cuenta from gv_movimientos a
       where a.fecha=P_fecha
       and a.hora=P_hora
       and a.nro_documento=P_nro_documento
       and a.nro_cuenta is not null
       and rownum=1;
       return nvl(v_nro_cuenta,'0');
exception
       when others then 
            return null;
            raise_application_error(-20000,'Erro al buscar cuenta:'||P_nro_documento||sqlerrm);

    

end;


--Funcion que obtien el cliente principal de la cuenta
Function Fu_obt_clt_principal(P_nro_cuenta in ge_cta_clientes.nro_cuenta%type)
return varchar2
is
v_cod_persona varchar(20);
begin
       select a.cod_persona into v_cod_persona
       from ge_cta_clientes a 
       where a.nro_cuenta=P_nro_cuenta
       and a.relacion='P';
       
       return nvl(v_cod_persona,'0');

exception
       when others then 
       return null;
            raise_application_error(-20000,'No se encuentra principal de la cuenta: '||P_nro_cuenta||sqlerrm);


end;


end PAI_DTM_T;
/

