CREATE OR REPLACE PACKAGE BODY IT.PAI_PSA IS
   -- Paquete utilizado para las interfaces ITGF y la herramienta PSAML
   -- Fecha: 30/04/2014
   -- Autor: Sergio Servín Arce
   ---------------------------------------------------------------------------
   -- Declaración de variables privadas
   V_NOM_ARCHIVO VARCHAR2(30);
   --V_SQL         VARCHAR2(3000);
   V_FEC_PROCESO DATE;
   V_REPROCESO   VARCHAR2(1) := 'N';

   -- FUNCIONES --

   --FUNCIÓN UTILIZADO EN PSAML QUE BUSCA LOS COD DE ITGF CARGADOS COMO CATÁLOGOS
  FUNCTION FU_OBT_COD_BTL_PSA(P_VAL_ITGF VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       AND T.VAL_COD_ITGF = P_VAL_ITGF;

    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 99;
  END;

  FUNCTION FU_OBT_COD_BTL_PSA(P_VAL1_ITGF VARCHAR2, P_VAL2_ITGF VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       AND T.VAL_COD_ITGF = P_VAL1_ITGF
       AND T.VAL_COD_ITGF2 = P_VAL2_ITGF;

    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 99;
  END;

  FUNCTION FU_OBT_DES_CIU_BTL_PSA(P_COD_CIU_ITGF  VARCHAR2,
                                  P_COD_PAIS_ITGF VARCHAR2) RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN

    BEGIN
      SELECT P.DESCRIPCION
        INTO V_COD_BANTOTAL
        FROM BA_CIUDADES P
       WHERE P.COD_CIUDAD = P_COD_CIU_ITGF
         AND P.COD_PAIS = P_COD_PAIS_ITGF;
         return V_COD_BANTOTAL;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN 1;
      WHEN OTHERS THEN
        RETURN 99;
    END;

    end;

    FUNCTION FU_OBT_COD_CIU_BT(P_COD_CIU_ITGF  VARCHAR2,
                             P_COD_PAIS_ITGF VARCHAR2,
                             P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       and T.VAL_COD_ITGF2 = P_COD_PAIS_ITGF
       AND T.VAL_COD_ITGF = P_COD_CIU_ITGF;

    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

  FUNCTION FU_OBT_COD_REF_BT(P_DOMINIO VARCHAR2, P_VAL_ITGF VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = 'BA_COD_REFERENCIAS'
       AND T.DOM_REF_ITGF = P_DOMINIO
       AND T.VAL_COD_ITGF = P_VAL_ITGF;
    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;


   FUNCTION FU_OBT_COD_ITGF(P_VAL_BT VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_IT mi_tab_parametricas.Val_Cod_Itgf%type;
  BEGIN
    SELECT T.VAL_COD_ITGF
      INTO V_COD_IT
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       AND T.VAL_COD_BANTOTAL = P_VAL_BT;

    RETURN V_COD_IT;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;


  FUNCTION FU_OBT_SEG_CLIENTE(P_COD_PERSONA IN VARCHAR2) RETURN VARCHAR2 IS
     v_segmento varchar2(50);
  BEGIN
     SELECT SEGMENTO
       INTO v_segmento
       FROM (SELECT nvl(b.significado, a.SGTO_VALOR_2013) SEGMENTO
               FROM dw_cli_segmentos   a,
                    ba_cod_referencias b,
                    ba_cod_referencias c
              WHERE to_number(a.NU_CTE) = to_number(P_COD_PERSONA)
                and a.SGTO_VALOR_2013 = b.val_minimo(+)
                and b.dominio(+) = 'DES_SEG_ESTRUCTURAL'
                and a.SGTO_ACIDO_ESTRUCTURAL = c.val_minimo(+)
                and c.dominio(+) = 'DES_SUB_SEG_ESTRUCTURAL'
              ORDER BY FH_INFORMACION desc)
      WHERE rownum = 1;
     return v_Segmento;
  END;
   
  --- DYDMR-22618
   PROCEDURE PR_LOG_PSAML(P_DAT1 IN VARCHAR2 default null,
                          P_DAT2 IN VARCHAR2 default null,
                          P_DAT3 IN VARCHAR2 default null,
                          P_DAT4 IN VARCHAR2 default null) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO MI_PSA_LOG_PROCESOS
         SELECT seq_psa_actividad.NEXTVAL,
                sysdate,
                P_DAT1,
                P_DAT2,
                P_DAT3,
                P_DAT4
           FROM DUAL;
      COMMIT;
   END;
  
 PROCEDURE PR_PRO_SEG_CLIENTE IS
    cursor c_clientes is
       select distinct a.cod_persona from ge_cta_imp_psaml a
       where a.seg_cliente is null;
    v_segmento varchar2(100);
 BEGIN
    for c in c_clientes loop
       --tool_pro_log_proceso(SYSDATE, C.COD_PERSONA||' act segmento');
       begin

          SELECT
           nvl(b.significado, a.SGTO_VALOR_2013) SEGMENTO
            into v_segmento
            FROM dw_cli_segmentos   a,
                 ba_cod_referencias b
           WHERE to_number(a.NU_CTE) = to_number(c.COD_PERSONA)
             and a.SGTO_VALOR_2013 = b.val_minimo(+)
             and b.dominio(+) = 'DES_SEG_ESTRUCTURAL'
             AND ROWNUM = 1;
       exception
          when no_data_found then
             v_segmento := 'SIN SEGMENTO';
          when others then
             V_SEGMENTO := 'ERROR';
       end;

       update Ge_Cta_Imp_Psaml s
          set s.seg_cliente = v_Segmento
        WHERE S.COD_PERSONA = C.COD_PERSONA;

    end loop;


 END;

 PROCEDURE PR_PRO_CTA_CON_MOVIMIENTOS(P_FEC_DESDE IN DATE,
                                      P_FEC_HASTA IN DATE) IS
 BEGIN
    delete psa006
     where psa006do in
           (SELECT psa006do
              FROM PSA006
             where psa006ct not in
                   (select psa003nc
                      from psa003 m
                     where TO_dATE(m.psa003ft, 'RRRRMMDD') between
                           P_FEC_DESDE and
                           P_FEC_HASTA));


 END;

  PROCEDURE PR_PRO_OFICIAL_CLIENTE(P_FEC_PROCESO IN DATE) IS
     cursor c_clientes is
        select distinct a.cod_persona,
                        NVL(P.COD_PAI_DOCUMENTO, P.COD_PAIS) COD_PAIS,
                        P.COD_TIP_DOCUMENTO,
                        P.NRO_DOCUMENTO
          from ge_cta_imp_psaml a,
               GE_CLIENTES      CL,
               BA_PERSONAS      P
         WHERE A.COD_PERSONA = CL.COD_PERSONA
           AND P.COD_PERSONA = A.COD_PERSONA
           AND (a.cod_ofi_bantotal is null OR TRUNC(CL.FEC_MODIFICACION) >= P_FEC_PROCESO or a.cod_ofi_bantotal = 777);
     V_COD_OFICIAL_BTL NUMBER(9);
     v_cantidad        number(5):=0;
  BEGIN
     FOR C IN C_CLIENTES LOOP
        --DBMS_OUTPUT.put_line('CLIENTE:'||C.COD_PERSONA);
        SELECT PAI_PSA.FU_OBT_OFI_BANTOTAL(CL.COD_USU_OFICIAL) INTO V_COD_OFICIAL_BTL FROM GE_CLIENTES CL WHERE CL.COD_PERSONA = C.COD_PERSONA;
     
        UPDATE GE_CTA_IMP_PSAML T
           SET T.COD_OFI_BANTOTAL = V_COD_OFICIAL_BTL
         WHERE T.COD_PERSONA = C.COD_PERSONA
           AND T.COD_OFI_BANTOTAL != V_COD_OFICIAL_BTL;
        --ACTUALIZACIÓN DE REGISTRO DE CUENTAS PSAML (ACTUALIZACIÓN DE OFICIALES)
        IF V_COD_OFICIAL_BTL != 777 THEN
           --DBMS_OUTPUT.put_line('CLIENTE:'||C.COD_PERSONA||' OFICIAL:'||V_COD_OFICIAL_BTL);
           UPDATE PSA006 PCTA
              SET PCTA.PSA006EJ = V_COD_OFICIAL_BTL
            WHERE PCTA.PSA006PA = PAI_PSA.FU_OBT_COD_BTL_PSA(C.COD_PAIS, 'BA_PAISES')
              AND PCTA.PSA006TD = PAI_PSA.FU_OBT_COD_BTL_PSA(C.COD_TIP_DOCUMENTO, 'BA_TIP_DOCUMENTOS')
              AND PCTA.PSA006DO = C.NRO_DOCUMENTO
              AND PCTA.PSA006EJ != V_COD_OFICIAL_BTL;
        END IF;
     
     END LOOP;
     commit;
  
     --actualización masiva de los que fueron actualizados por fuera de itgf
     begin
     
        select count(*) into v_Cantidad from psa006 where psa006ej = 777;
        if v_Cantidad > 0 then
           begin
              update psa006
                 set psa006ej = pai_psa.FU_OBT_OFI_BANTOTAL((select c.cod_usu_oficial
                                                              from ba_personas p,
                                                                   ge_clientes c
                                                             where p.cod_persona = c.cod_persona
                                                               and p.nro_documento = psa006do
                                                               and rownum = 1))
               where psa006ej = 777;
           end;
        end if;
     
     end;
     commit;
  END;



   -- Función que obtiene la fecha de proceso
   FUNCTION FU_OBT_FEC_PROCESO RETURN DATE IS
   BEGIN
      IF V_REPROCESO = 'S' THEN
         RETURN TO_DATE(fug_obt_pardinamico('FEC_PRO_PSAML'), 'DD/MM/YYYY');
      ELSE
         RETURN pag_cal.fu_obt_fec_actual(4);

      END IF;
   END;

   --ACTUALIZACIÓN DE TOTAL ACTIVO Y PASIVO DEL CLIENTE
   PROCEDURE PR_ACT_PAS_ACT_CLIENTE IS
      SQL_TXT VARCHAR2(500);
   BEGIN
      BEGIN
         --SE BORRA LOS REGISTROS DE LA TABLA
         SQL_TXT := 'TRUNCATE TABLE MI_PSA_CLI_SALDOS';
         EXECUTE IMMEDIATE SQL_TXT;
      END;

       BEGIN
          INSERT INTO MI_PSA_CLI_SALDOS
             Select t.cod_persona,
                    SUM(DECODE(T.ING_EGRESO, 'I', T.IMPORTE, 0)) total_ACTIVO,
                    SUM(DECODE(T.ING_EGRESO, 'E', T.IMPORTE, 0)) total_PASIVO
               from CR_PER_ING_EGRESOS t,
                    (select distinct a.cod_persona
                       from GE_CTA_IMP_PSAML a
                      where A.EXI_ENBANTOTAL = 'N') ct
              where t.cod_persona = ct.cod_persona
              GROUP BY t.cod_persona;
          /*select A.COD_PERSONA,
                SUM(DECODE(R.TIPO, 1, d.sal_actual, 0)) total_ACTIVO,
                SUM(DECODE(R.TIPO, 2, d.sal_actual, 0)) total_PASIVO
           from cb_sal_inventarios     c,
                cb_sal_inventarios_det d,
                CB_RUBROS              R,
                GE_CTA_IMP_PSAML       A
          where c.nro_referencia = d.nro_referencia
            AND C.COD_RUBRO = R.COD_RUBRO
            AND R.TIPO IN (1, 2)
            and d.nro_cuenta = A.NRO_CUENTA
            AND A.EXI_ENBANTOTAL = 'N'
          GROUP BY A.COD_PERSONA;*/
       END;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al procesar datos de activo y pasivo del cliente: ' ||
                                 sqlerrm);
   END;

   --Valida que las tablas de bantotal esten con registro para iniciar el proceso correcto de PSAML
   PROCEDURE PR_VAL_TAB_BANTOTAL IS
      V_HAY_DAT_FSD001 VARCHAR2(2);
      V_HAY_DAT_FST010 VARCHAR2(2);
      V_HAY_DAT_FST146 VARCHAR2(2);
      V_MENSAJE varchar2(2000);
   BEGIN
      BEGIN
         SELECT 'S' INTO V_HAY_DAT_FSD001 FROM FSD001 WHERE ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_HAY_DAT_FSD001 := 'N';
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Error al verificar registros de la FSD001: ' || sqlerrm);
      END;

      BEGIN
         SELECT 'S' INTO V_HAY_DAT_FST010 FROM FST010 WHERE ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_HAY_DAT_FST010 := 'N';
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Error al verificar registros de la FST010: ' || sqlerrm);
      END;

      BEGIN
         SELECT 'S' INTO V_HAY_DAT_FST146 FROM FST146 WHERE ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_HAY_DAT_FST146 := 'N';
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Error al verificar registros de la FST146: ' || sqlerrm);
      END;


      IF V_HAY_DAT_FSD001 = 'N' OR V_HAY_DAT_FST010 = 'N' OR V_HAY_DAT_FST146 = 'N' THEN
         SELECT 'No hay datos en la tabla (s) '
                 ||decode(V_HAY_DAT_FSD001,'N', ' FSD001 ',null)
                 ||decode(V_HAY_DAT_FST010,'N', ' FST010 ',null)
                 ||decode(V_HAY_DAT_FST146,'N', ' FST146 ',null)
         INTO V_MENSAJE
         FROM DUAL;

         RAISE_APPLICATION_ERROR(-20000, V_MENSAJE||'.. el proceso no puede continuar.');
      END IF;

   END;

   FUNCTION FU_OBT_SAL_CLI(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                          ,P_TIPO        VARCHAR2) RETURN NUMBER IS
      V_SALDO NUMBER(20);
   BEGIN
      IF P_TIPO = 'A' THEN
         --TOTAL ACTIVO
         select sum(a.importe)
         into V_SALDO
         from CR_PER_ING_EGRESOS a
         where a.cod_persona = P_COD_PERSONA
         and   a.ing_egreso = 'I';


         /*select SUM(d.sal_actual) total_pasivo
           INTO V_SALDO
           from cb_sal_inventarios     c
               ,cb_sal_inventarios_det d
          where c.nro_referencia = d.nro_referencia
            and substr(c.cod_rubro, 1, 1) = 1 --ACTIVO
            and d.nro_cuenta in
                (select a.nro_cuenta from GE_CTA_IMP_PSAML a where a.cod_persona = P_COD_PERSONA);*/
      ELSIF P_TIPO = 'P' THEN
         --TOTAL PASIVO
         select SUM(d.sal_actual) total_pasivo
           INTO V_SALDO
           from cb_sal_inventarios     c
               ,cb_sal_inventarios_det d
          where c.nro_referencia = d.nro_referencia
            and substr(c.cod_rubro, 1, 1) = 2 --PASIVO
            and d.nro_cuenta in
                (select a.nro_cuenta from GE_CTA_IMP_PSAML a where a.cod_persona = P_COD_PERSONA);
      ELSIF P_TIPO = 'E' THEN
         --TOTAL EGRESOS
         Select SUM(T.IMPORTE) TOTAL
           INTO V_SALDO
           from CR_PER_ING_EGRESOS T
          WHERE T.COD_PERSONA = P_COD_PERSONA
            and t.ing_egreso = 'E';
      ELSIF P_TIPO = 'I' THEN
         --TOTAL INGRESOS
         Select SUM(T.IMPORTE) TOTAL
           INTO V_SALDO
           from CR_PER_ING_EGRESOS T
          WHERE T.COD_PERSONA = P_COD_PERSONA
            and t.ing_egreso = 'I';
      END IF;
      RETURN V_SALDO;
   END;

   FUNCTION FU_OBT_EST_CIVIL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                            ,P_TIPO        IN VARCHAR2) RETURN VARCHAR2 IS
      V_EST_civil_bt mi_tab_parametricas.val_cod_bantotal%type;
   BEGIN
      IF P_TIPO = 'F' THEN
         declare
            v_est_itgf ba_per_fisicas.est_civil%type;
         begin
            select a.est_civil
              into v_est_itgf
              from ba_per_fisicas a
             where a.cod_persona = p_cod_persona;
            if v_est_itgf is not null then
               V_EST_civil_bt := PAI_PSA.FU_OBT_COD_REF_BT('COD_EST_CIVIL', v_est_itgf);
               if V_EST_civil_bt = '999' then
                  V_EST_civil_bt := 7;
               end if;
            end if;
         end;
      ELSE
         V_EST_civil_bt := null;
      end if;
      return V_EST_civil_bt;
   END;

   -- FunciÓn que obtiene el nombre del cliente
   FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                              ,P_TIPO        IN VARCHAR2
                              ,P_ORDEN       NUMBER) RETURN VARCHAR2 IS
      V_NOM_CLIENTE VARCHAR2(30);
   BEGIN
      V_NOM_CLIENTE := ' ';
      --
      IF P_TIPO = 'F' THEN
         -- Primer nombre de la persona Física
         BEGIN
            SELECT DECODE(P_ORDEN, 1, NVL(TRIM(F.PRI_NOMBRE), 'SIN NOMBRE'), 2,
                          NVL(TRIM(F.SEG_NOMBRE), 'SIN NOMBRE'))
              INTO V_NOM_CLIENTE
              FROM BA_PER_FISICAS F
             WHERE F.COD_PERSONA = P_COD_PERSONA;
            --
         EXCEPTION
            WHEN OTHERS THEN
               V_NOM_CLIENTE := 'SIN NOMBRE';
         END;

      END IF;
      --
      RETURN V_NOM_CLIENTE;
      --
   END;

   -- FunciÓn que obtiene el apellido del cliente
   FUNCTION FU_OBT_APE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                              ,P_TIPO        IN VARCHAR2
                              ,P_ORDEN       NUMBER) RETURN VARCHAR2 IS
      V_APE_CLIENTE VARCHAR2(70);
   BEGIN
      V_APE_CLIENTE := NULL;
      --
      IF P_TIPO = 'F' THEN
         -- Primer nombre de la persona Física
         BEGIN
            SELECT DECODE(P_ORDEN, 1, NVL(TRIM(F.PRI_APELLIDO), 'SIN APELLIDO'), 2,
                          NVL(TRIM(F.SEG_APELLIDO), 'SIN APELLIDO'))
              INTO V_APE_CLIENTE
              FROM BA_PER_FISICAS F
             WHERE F.COD_PERSONA = P_COD_PERSONA;
            --
         EXCEPTION
            WHEN OTHERS THEN
               V_APE_CLIENTE := 'SIN APELLIDO';
         END;
      ELSIF P_TIPO = 'J' THEN
         -- Nombre comercial persona jurídica
         BEGIN
            SELECT NVL(TRIM(J.NOM_COMERCIAL), 'S/D')
              INTO V_APE_CLIENTE
              FROM BA_PER_JURIDICAS J
             WHERE J.COD_PERSONA = P_COD_PERSONA;
         EXCEPTION
            WHEN OTHERS THEN
               V_APE_CLIENTE := 'SIN APELLIDO';
         END;
      END IF;
      --
      RETURN V_APE_CLIENTE;
      --
   END;

   -- Función que obtiene la descripción del tipo de documento
   FUNCTION FU_OBT_DES_TIP_DOC(P_COD_TIP_DOCUMENTO IN BA_TIP_DOCUMENTOS.COD_TIP_DOCUMENTO%TYPE)
      RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE IS
      V_DES_TIP_DOCUMENTO BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE;
   BEGIN
      SELECT DESCRIPCION
        INTO V_DES_TIP_DOCUMENTO
        FROM BA_TIP_DOCUMENTOS A
       WHERE COD_TIP_DOCUMENTO = P_COD_TIP_DOCUMENTO;

      RETURN V_DES_TIP_DOCUMENTO;
   EXCEPTION
      WHEN OTHERS THEN
         Return ' ';
   END;

   -- Función que obtiene la descripción de la actividad
   FUNCTION FU_OBT_DES_ACTIVIDAD(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                                ,P_TIP_PERSONA VARCHAR2) RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE IS
      V_DES_ACTIVIDAD VARCHAR2(60);
   BEGIN
      IF P_TIP_PERSONA = 'F' THEN
         -- Persona Física
         BEGIN
            SELECT NVL(p.descripcion, ' ')
              INTO V_DES_ACTIVIDAD
              FROM ba_per_fisicas f
                  ,ba_profesiones p
             WHERE f.cod_persona = p_cod_persona
               AND f.cod_profesion = p.cod_profesion;
         EXCEPTION
            WHEN OTHERS THEN
               return ' ';
         END;
      ELSE
         -- Persona Jurídica
         BEGIN
            SELECT a.descripcion
              INTO V_DES_ACTIVIDAD
              FROM ba_personas    f
                  ,ge_actividades a
             WHERE f.cod_persona = p_cod_persona
               AND f.cod_actividad = a.cod_actividad;
         EXCEPTION
            WHEN OTHERS THEN
               return ' ';
         END;
      END IF;

      RETURN V_DES_ACTIVIDAD;
   EXCEPTION
      WHEN OTHERS THEN
         Return NULL;
   END;

   -- Función que obtiene la fecha de nacimiento
   FUNCTION FU_OBT_FEC_NACIMIENTO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                                 ,P_TIP_PERSONA VARCHAR2) RETURN date IS
      V_FEC_NACIMIENTO DATE;
   BEGIN
      IF P_TIP_PERSONA = 'F' THEN
         -- Persona Física
         BEGIN
            SELECT f.fec_nacimiento
              INTO V_FEC_NACIMIENTO
              FROM ba_per_fisicas f
             WHERE f.cod_persona = p_cod_persona;
         EXCEPTION
            WHEN OTHERS THEN
               return TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
         END;
      ELSE
         -- Fecha apertura Persona Jurídica
         BEGIN
            SELECT j.fec_apertura
              INTO V_FEC_NACIMIENTO
              FROM ba_per_juridicas j
             WHERE j.cod_persona = p_cod_persona;
         EXCEPTION
            WHEN OTHERS THEN
               return TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
         END;
      END IF;
      --
      /*IF ( ( V_FEC_INGRESO < TO_DATE('01/01/1950','dd/mm/yyyy') ) OR
      ( TO_NUMBER(TO_CHAR(V_FEC_INGRESO,'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')))) THEN*/
      IF V_FEC_NACIMIENTO IS NOT NULL THEN
         IF (V_FEC_NACIMIENTO < TO_DATE('01/01/1653', 'DD/MM/YYYY')) OR
            (TO_NUMBER(TO_CHAR(V_FEC_NACIMIENTO, 'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY'))) THEN
            RETURN TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
         ELSE
            RETURN V_FEC_NACIMIENTO;
         END IF;
      ELSE
         RETURN TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
      END IF;
      --
   EXCEPTION
      WHEN OTHERS THEN
         Return TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
   END;

   -- Función que obtiene el código ISO del pais
   FUNCTION FU_OBT_COD_ISO_PAIS(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE
                               ,P_TIP_BUSQUEDA VARCHAR2
                               ,P_COD_PAIS     BA_PAISES.COD_PAIS%TYPE)
      RETURN GE_AST_PAISES.COD_AST_PAIS%TYPE IS
      V_COD_ISO_PAIS GE_AST_PAISES.COD_AST_PAIS%TYPE;
   BEGIN
      IF P_COD_PERSONA IS NOT NULL THEN
         IF P_TIP_BUSQUEDA = 'N' THEN
            -- Pais de Nacionalización
            BEGIN
               SELECT P.COD_AST_PAIS
                 INTO V_COD_ISO_PAIS
                 FROM BA_PERSONAS   PE
                     ,GE_AST_PAISES P
                WHERE PE.COD_PERSONA = P_COD_PERSONA
                  AND PE.COD_PAIS = P.COD_PAIS;
            EXCEPTION
               WHEN OTHERS THEN
                  V_COD_ISO_PAIS := 'PRY';
            END;
         ELSE
            -- Pais de la Dirección
            BEGIN
               SELECT P.COD_AST_PAIS
                 INTO V_COD_ISO_PAIS
                 FROM BA_DIRECCIONES D
                     ,GE_AST_PAISES  P
                WHERE D.COD_PERSONA = P_COD_PERSONA
                  AND D.COD_PAIS = P.COD_PAIS
                  AND D.PRINCIPAL = 'S';
            EXCEPTION
               WHEN OTHERS THEN
                  V_COD_ISO_PAIS := 'PRY';
            END;
         END IF;
      END IF;
      --
      IF P_COD_PERSONA IS NULL THEN
         BEGIN
            SELECT A.COD_AST_PAIS
              INTO V_COD_ISO_PAIS
              FROM GE_AST_PAISES A
             WHERE A.COD_PAIS = P_COD_PAIS;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN ' ';
         END;
      END IF;

      RETURN V_COD_ISO_PAIS;
   END;

   -- Función que obtiene la dirección principal
   FUNCTION FU_OBT_DIR_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                                ,p_tipo        in varchar2) RETURN VARCHAR2 IS
      V_DIRECCION BA_DIRECCIONES.DIRECCION%TYPE;
   BEGIN
      if p_tipo = 'P' then
         --particular
         begin
            SELECT DI.DIRECCION
              INTO V_DIRECCION
              FROM BA_DIRECCIONES DI
             WHERE DI.COD_PERSONA = P_COD_PERSONA
               AND DI.TIPO = 'P';
         end;
      elsif p_tipo = 'L' then
         --laboral
         begin
            SELECT DI.DIRECCION
              INTO V_DIRECCION
              FROM BA_DIRECCIONES DI
             WHERE DI.COD_PERSONA = P_COD_PERSONA
               AND DI.TIPO = 'L';
         end;
      elsif p_tipo = 'PP' then
         --principal
         begin
            SELECT DI.DIRECCION
              INTO V_DIRECCION
              FROM BA_DIRECCIONES DI
             WHERE DI.COD_PERSONA = P_COD_PERSONA
               AND DI.Principal = 'S';
         end;
      end if;
      --
      RETURN V_DIRECCION;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN ' ';
   END;
   -- Función que obtiene la descripción del departamento
   FUNCTION FU_OBT_DES_DEP_CIU_POS(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE
                                  ,P_TIP_BUSQUEDA VARCHAR2) RETURN VARCHAR2 IS
      V_DES_DEP_CIU_POS VARCHAR2(50);
   BEGIN
      IF P_TIP_BUSQUEDA = 'D' THEN
         -- DEPARTAMENTO
         BEGIN
            SELECT DE.COD_DEPARTAMENTO
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES   D
                  ,BA_CIUDADES      C
                  ,BA_DEPARTAMENTOS DE
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.COD_PAIS = C.COD_PAIS
               AND D.COD_CIUDAD = C.COD_CIUDAD
               AND C.COD_DEPARTAMENTO = DE.COD_DEPARTAMENTO
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      ELSIF P_TIP_BUSQUEDA = 'C' THEN
         -- CIUDAD
         BEGIN
            SELECT nvl(C.DESCRIPCION, ' ')
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES D
                  ,BA_CIUDADES    C
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.COD_PAIS = C.COD_PAIS
               AND D.COD_CIUDAD = C.COD_CIUDAD
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      ELSE
         -- COD. POSTAL
         BEGIN
            SELECT NVL(D.COD_POSTAL, ' ')
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES D
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      END IF;
      RETURN V_DES_DEP_CIU_POS;
   END;
   -- Función que obtiene la descripción del departamento
   FUNCTION FU_OBT_COD_CIU(P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE
                          ,P_TIP_BUSQUEDA VARCHAR2) RETURN VARCHAR2 IS
      V_DES_DEP_CIU_POS VARCHAR2(50);
   BEGIN
      IF P_TIP_BUSQUEDA = 'D' THEN
         -- DEPARTAMENTO
         BEGIN
            SELECT DE.COD_DEPARTAMENTO
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES   D
                  ,BA_CIUDADES      C
                  ,BA_DEPARTAMENTOS DE
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.COD_PAIS = C.COD_PAIS
               AND D.COD_CIUDAD = C.COD_CIUDAD
               AND C.COD_DEPARTAMENTO = DE.COD_DEPARTAMENTO
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      ELSIF P_TIP_BUSQUEDA = 'C' THEN
         -- CIUDAD
         BEGIN
            SELECT C.COD_CIUDAD
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES D
                  ,BA_CIUDADES    C
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.COD_PAIS = C.COD_PAIS
               AND D.COD_CIUDAD = C.COD_CIUDAD
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      ELSIF P_TIP_BUSQUEDA = 'CL' THEN
         -- CIUDAD laboral
         BEGIN
            SELECT C.COD_CIUDAD
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES D
                  ,BA_CIUDADES    C
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.COD_PAIS = C.COD_PAIS
               AND D.COD_CIUDAD = C.COD_CIUDAD
               AND D.tipo = 'L'
               AND ROWNUM = 1;
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      ELSE
         -- COD. POSTAL
         BEGIN
            SELECT NVL(D.COD_POSTAL, ' ')
              INTO V_DES_DEP_CIU_POS
              FROM BA_DIRECCIONES D
             WHERE D.COD_PERSONA = P_COD_PERSONA
               AND D.PRINCIPAL = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               V_DES_DEP_CIU_POS := ' ';
         END;
      END IF;
      RETURN V_DES_DEP_CIU_POS;
   END;
   -- Función que obtiene la dirección principal
   FUNCTION FU_OBT_TEL_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
                                ,p_tipo        in varchar2) RETURN VARCHAR2 IS
      V_TELEFONO BA_TELEFONOS.TELEFONO%TYPE;
   BEGIN
      if p_tipo = 'F' then
         begin
            SELECT TE.TELEFONO
              INTO V_TELEFONO
              FROM BA_TELEFONOS TE
             WHERE TE.COD_PERSONA = P_COD_PERSONA
               AND TE.TIPO = 'P'
               AND TE.TIP_LINEA = 'B'
               AND PRINCIPAL = 'S';
         end;
      elsif p_tipo != 'P' then
         begin
            SELECT TE.TELEFONO
              INTO V_TELEFONO
              FROM BA_TELEFONOS TE
             WHERE TE.COD_PERSONA = P_COD_PERSONA
               AND TE.TIPO = 'P'
               AND TE.TIP_LINEA = 'B'
               AND PRINCIPAL != 'S'
               and rownum = 1;
         end;
      end if;
      RETURN V_TELEFONO;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN ' ';
   END;

   -- Función que obtiene si está o no en la lista PEP
   FUNCTION FU_OBT_PEP(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN CR_INF_FONDOS.PEP%TYPE IS
      V_PEP CR_INF_FONDOS.PEP%TYPE;
   BEGIN
      SELECT DECODE(NVL(A.PEP, 'N'), 'N', 'N', 'Y')
        INTO V_PEP
        FROM CR_INF_FONDOS A
       WHERE A.COD_PERSONA = P_COD_PERSONA;

      RETURN V_PEP;
   EXCEPTION
      WHEN OTHERS THEN
         Return 'N';
   END;

   -- Función que obtiene el código de Herencia
   FUNCTION FU_OBT_COD_HERENCIA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
      V_COD_HERENCIA BA_PERSONAS.COD_PERSONA%TYPE;
   BEGIN
      SELECT DECODE(NVL(A.FON_HERENCIA, 'N'), 'S', 6, ' ')
        INTO V_COD_HERENCIA
        FROM CR_INF_FONDOS A
       WHERE COD_PERSONA = P_COD_PERSONA;

      RETURN V_COD_HERENCIA;
   EXCEPTION
      WHEN OTHERS THEN
         Return ' ';
   END;

   -- Función que obtiene la región de la cuenta
   FUNCTION FU_OBT_REGION_CUENTA(P_COD_OFICINA IN GE_CLIENTES.COD_OFICINA%TYPE) RETURN VARCHAR2 IS
      V_REGION_CUENTA BA_DEPARTAMENTOS.COD_DEPARTAMENTO%TYPE;
   BEGIN
      --
      SELECT CI.COD_DEPARTAMENTO
        INTO V_REGION_CUENTA
        FROM BA_OFICINAS OFI
            ,BA_CIUDADES CI
       WHERE OFI.COD_CIUDAD = CI.COD_CIUDAD
         AND OFI.COD_PAIS = CI.COD_PAIS
         AND OFI.COD_OFICINA = P_COD_OFICINA;
      --
      RETURN V_REGION_CUENTA;
   EXCEPTION
      WHEN OTHERS THEN
         Return ' ';
   END;

   -- Función que obtiene el ingreso del cliente
   FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE) RETURN DATE IS
      V_FEC_INGRESO DATE;
   BEGIN
      SELECT A.FEC_INGRESO
        INTO V_FEC_INGRESO
        FROM GE_CLIENTES A
       WHERE A.COD_PERSONA = P_COD_PERSONA;

      IF ((V_FEC_INGRESO < TO_DATE('01/01/1950', 'dd/mm/yyyy')) OR
         (TO_NUMBER(TO_CHAR(V_FEC_INGRESO, 'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY')))) THEN
         RETURN TO_DATE('01/01/2001', 'MM/DD/YYYY');
      ELSE
         RETURN V_FEC_INGRESO;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN TO_DATE('01/01/2001', 'MM/DD/YYYY');
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al buscar fecha del cliente Nro:' || P_COD_PERSONA ||
                                  SQLERRM);
   END;

   -- Función que obtiene la fecha cerrada o cancelada de la cuenta
   -- Valores para P_TIPO
   -- 1 - LOS PRÉSTAMOS LA FECHA DE VENCIMIENTO
   -- 2 - Cancelada
   FUNCTION FU_OBT_FEC_CANCELACION(P_NRO_CUENTA    IN GE_CUENTAS.NRO_CUENTA%TYPE
                                  ,P_COD_MODULO    IN GE_MODALIDADES.COD_MODULO%TYPE
                                  ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
                                  ,P_TIPO          IN VARCHAR2) RETURN date IS
      V_FECHA DATE;
   BEGIN
      CASE
         WHEN P_TIPO = 1 THEN
            IF P_COD_MODULO = 6 THEN
               --buscar la fecha de vencimiento en pr_cta_prestamos
               BEGIN
                  SELECT T.FEC_VENCIMIENTO
                    INTO V_FECHA
                    from PR_CTA_PRESTAMOS T
                   WHERE T.NRO_CUENTA = P_NRO_CUENTA;
               EXCEPTION
                  WHEN OTHERS THEN
                     RAISE_APPLICATION_ERROR(-20000,
                                             'Error al buscar la fecha de vencimiento del préstamo' ||
                                              sqlerrm);
               END;
               RETURN TO_CHAR(V_FECHA, 'MM/DD/YYYY');

            ELSE
               --RETORNA LA FECHA DE MADURACIÓN INGRESADA POR PARÁMETRO.
               RETURN TO_DATE(PAI_PSA.FU_OBT_FEC_MADURACION, 'DD/MM/YYYY');
            END IF;

      --
         WHEN P_TIPO = 2 THEN
            CASE
               WHEN P_COD_MODALIDAD = 31 THEN
                  BEGIN
                     SELECT A.FEC_CAM_ESTADO
                       INTO V_FECHA
                       FROM GE_CUENTAS A
                      WHERE A.ESTADO IN ('C', 'P')
                        AND A.NRO_CUENTA = P_NRO_CUENTA;
                     --
                     IF V_FECHA IS NOT NULL THEN
                        RETURN TO_CHAR(V_FECHA, 'MM/DD/YYYY');
                     ELSE
                        RETURN ' ';
                     END IF;
                     --
                  EXCEPTION
                     WHEN OTHERS THEN
                        RETURN ' ';
                  END;
                  --
               WHEN P_COD_MODALIDAD IN (32, 33, 41, 42, 45, 442, 455) THEN
                  BEGIN
                     SELECT A.FEC_CAM_ESTADO
                       INTO V_FECHA
                       FROM GE_CUENTAS A
                      WHERE A.ESTADO IN ('C')
                        AND A.NRO_CUENTA = P_NRO_CUENTA;
                     --
                     IF V_FECHA IS NOT NULL THEN
                        RETURN TO_CHAR(V_FECHA, 'MM/DD/YYYY');
                     ELSE
                        RETURN ' ';
                     END IF;
                     --
                  EXCEPTION
                     WHEN OTHERS THEN
                        RETURN ' ';
                  END;
                  --
               WHEN P_COD_MODULO = 6 THEN
                  BEGIN

                     BEGIN
                        SELECT T.Fec_Cancelacion
                          INTO V_FECHA
                          from PR_CTA_PRESTAMOS T
                         WHERE T.NRO_CUENTA = P_NRO_CUENTA;
                     EXCEPTION
                        WHEN OTHERS THEN
                           RAISE_APPLICATION_ERROR(-20000,
                                                   'Error al buscar la fecha de Cancelación del préstamo: ' ||
                                                    sqlerrm);
                     END;
                     --
                     IF V_FECHA IS NOT NULL THEN
                        RETURN TO_CHAR(V_FECHA, 'MM/DD/YYYY');
                     ELSE
                        RETURN ' ';
                     END IF;
                     --
                  EXCEPTION
                     WHEN OTHERS THEN
                        RETURN ' ';
                  END;
                  --
            END CASE;
      END CASE;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al buscar fecha del cliente Nro:' || P_NRO_CUENTA ||
                                  SQLERRM);
   END;

   -- Función que recupera la fecha de implementación de ASSIST
   FUNCTION FU_OBT_FEC_IMP_ASSIST RETURN DATE IS
      l_fec_imp_assist varchar2(10);
   BEGIN
      l_fec_imp_assist := fug_obt_pardinamico('FEC_IMP_ASSIST');
      IF l_fec_imp_assist IS NULL THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al buscar la fecha de implementación ASSIST ' || sqlerrm);
      ELSE
         RETURN TO_DATE(l_fec_imp_assist, 'DD/MM/yyyy');
      END IF;
   END;

   -- Función que recupera la fecha de maduración (a partir de que fecha se tomaría para las alertas)
   FUNCTION FU_OBT_FEC_MADURACION RETURN VARCHAR2 IS
      l_fec_maduracion varchar2(10);
   BEGIN
      l_fec_maduracion := fug_obt_pardinamico('FEC_MAD_ASSIST');
      IF l_fec_maduracion IS NULL THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al buscar la fecha de maduración para ASSIST ' || sqlerrm);
      ELSE
         RETURN TO_CHAR(TO_DATE(l_fec_maduracion, 'DD/MM/YYYY'), 'MM/DD/YYYY');
      END IF;
   END;

   -- Función que recupera el código de proposito
   FUNCTION FU_OBT_COD_PRO_CUENTAS(P_PROPOSITO GE_PRO_CUENTAS.DESCRIPCION%TYPE) RETURN VARCHAR2 IS
      v_cod_pro_cuenta ge_pro_cuentas.cod_proposito%type;
   BEGIN

      SELECT COD_PROPOSITO
        INTO v_cod_pro_cuenta
        FROM GE_PRO_CUENTAS
       WHERE DESCRIPCION = P_PROPOSITO;

      RETURN v_cod_pro_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN ' ';
   END;

   -- Función que recupera el proposito de la cuenta
   FUNCTION FU_OBT_PRO_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
      CURSOR C_PRO IS
         SELECT FON.COD_PERSONA
               ,FON.PRO_INGRESOS
               ,FON.PRO_AHORROS
               ,FON.PRO_VEN_ALQ
               ,FON.PRO_GAS_OPERATIVOS
               ,FON.PRO_OTROS
           FROM CR_INF_FONDOS FON
          WHERE COD_PERSONA = P_COD_PERSONA;

      v_cod_proposito ge_pro_cuentas.cod_proposito%type;
   BEGIN
      v_cod_proposito := 0;
      --
      FOR F_PRO IN C_PRO LOOP
         IF F_PRO.PRO_INGRESOS = 'S' THEN
            RETURN PAI_PSA.FU_OBT_COD_PRO_CUENTAS('INGRESOS');
         ELSE
            IF F_PRO.PRO_AHORROS = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_PRO_CUENTAS('AHORROS');
            ELSE
               IF F_PRO.PRO_VEN_ALQ = 'S' THEN
                  RETURN PAI_PSA.FU_OBT_COD_PRO_CUENTAS('VENTA/ALQUILERES');
               ELSE
                  IF F_PRO.PRO_GAS_OPERATIVOS = 'S' THEN
                     RETURN PAI_PSA.FU_OBT_COD_PRO_CUENTAS('GASTOS OPERATIVOS');
                  ELSE
                     IF F_PRO.PRO_OTROS IS NOT NULL THEN
                        RETURN PAI_PSA.FU_OBT_COD_PRO_CUENTAS(UPPER(F_PRO.PRO_OTROS));
                     END IF;
                  END IF;
               END IF;
            END IF;
         END IF;
      END LOOP;

      RETURN v_cod_proposito;
   END;

   -- Función que recupera el tipo de objetivo de la cuenta
   FUNCTION FU_OBT_TIP_OBJ_CUENTA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
      v_cod_tip_obj_cuenta ba_per_dat_adicionales.val_parametro%type;
   BEGIN
      SELECT A.VAL_PARAMETRO
        INTO v_cod_tip_obj_cuenta
        FROM BA_PER_DAT_ADICIONALES A
       WHERE A.PARAMETRO = 'DTM_RIESGO'
         AND COD_PERSONA = P_COD_PERSONA;

      RETURN v_cod_tip_obj_cuenta;
      --
   EXCEPTION
      WHEN OTHERS THEN
         RETURN '311';
   END;

   -- Función que recupera el código de fuente de fondo de la cuenta
   FUNCTION FU_OBT_COD_FON_CUENTAS(P_FONDO GE_ORI_FONDOS.DESCRIPCION%TYPE) RETURN VARCHAR2 IS
      v_cod_fon_cuenta ge_ori_fondos.cod_ori_fondo%type;
   BEGIN

      SELECT COD_ORI_FONDO INTO v_cod_fon_cuenta FROM GE_ORI_FONDOS WHERE DESCRIPCION = P_FONDO;

      RETURN v_cod_fon_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN '0';
   END;

   -- Función que recupera el fuente de fondos de la cuenta
   FUNCTION FU_OBT_FON_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
      CURSOR C_FON IS
         SELECT FON.COD_PERSONA
               ,FON.FON_TRANSFERENCIAS
               ,FON.FON_SALARIO
               ,FON.FON_PRESTAMOS
               ,FON.FON_VTA_ACTIVOS
               ,FON.FON_REN_FINANCIERAS
               ,FON.FON_HERENCIA
               ,FON.FON_AHORRO
               ,FON.FON_PROPIO
               ,FON.FON_OTROS
           FROM CR_INF_FONDOS FON
          WHERE COD_PERSONA = P_COD_PERSONA;

      v_cod_fon_cuenta ge_ori_fondos.cod_ori_fondo%type;
   BEGIN
      v_cod_fon_cuenta := 0;
      --
      FOR F_FON IN C_FON LOOP
         CASE
            WHEN F_FON.FON_TRANSFERENCIAS = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('TRANSFERENCIA');
            WHEN F_FON.FON_SALARIO = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('SALARIO');
            WHEN F_FON.FON_PRESTAMOS = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('PRESTAMOS');
            WHEN F_FON.FON_VTA_ACTIVOS = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('VENTA DE ACTIVOS');
            WHEN F_FON.FON_REN_FINANCIERAS = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('RENOVACIONES FINANCIERAS');
            WHEN F_FON.FON_HERENCIA = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('HERENCIA');
            WHEN F_FON.FON_AHORRO = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('AHORRO');
            WHEN F_FON.FON_PROPIO = 'S' THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS('PROPIOS');
            WHEN F_FON.FON_OTROS IS NOT NULL THEN
               RETURN PAI_PSA.FU_OBT_COD_FON_CUENTAS(UPPER(F_FON.FON_OTROS));
            ELSE
               RETURN 0;
         END CASE;

      END LOOP;

      RETURN v_cod_fon_cuenta;
   END;

   -- Función que retorna la descripción del banco
   FUNCTION FU_OBT_DES_BANCO(P_COD_BANCO LC_TRANSFERENCIAS.COD_BCO_CORRESPONSAL%TYPE
                            ,P_SIGLA     GE_BANCOS.SIGLA%TYPE) RETURN VARCHAR2 IS
      V_DES_BANCO GE_BANCOS.DESCRIPCION%TYPE;
      V_SIGLA     VARCHAR2(8);
   BEGIN
      SELECT A.DESCRIPCION
            ,SUBSTR(A.DESCRIPCION, 1, 8)
        INTO V_DES_BANCO
            ,V_SIGLA
        FROM GE_BANCOS A
       WHERE A.COD_BANCO = P_COD_BANCO;

      IF P_SIGLA = 'S' THEN
         RETURN V_SIGLA;
      ELSE
         RETURN V_DES_BANCO;
      END IF;
      --
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN ' ';
   END;

   --Función que retorna la descripción del Banco Originador en transacciones SNP (interbanco)
   FUNCTION FU_OBT_DES_BAN_SNP(P_NRO_CTA_BANCARIA GE_SNP_CTA_BANCOS.NRO_CTA_BANCARIA%TYPE)
      RETURN VARCHAR2 IS
      V_DES_BANCO GE_BANCOS.DESCRIPCION%TYPE;

   BEGIN
      BEGIN
         --primero buscamos en la tabla de bancos
         SELECT PAI_PSA.FU_OBT_DES_BANCO(A.COD_BANCO, 'N')
           INTO V_DES_BANCO
           FROM GE_SNP_CTA_BANCOS A
          WHERE A.Nro_Cta_Bancaria = P_NRO_CTA_BANCARIA;
         RETURN V_DES_BANCO;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            --si no se encuentra datos en bancos, buscar en tabla de los entes
            BEGIN
               SELECT fue_obt_nom_ente(A.COD_ENTE)
                 INTO V_DES_BANCO
                 FROM GE_SNP_CTA_ENTES A
                WHERE A.Nro_Cta_Bancaria = P_NRO_CTA_BANCARIA;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  V_DES_BANCO := ' ';
            END;
      END;

      RETURN V_DES_BANCO;

   END;

   -- Obtiene datos de la transferencia.
   FUNCTION FU_OBT_DAT_TRANSFERENCIA(P_NRO_OPERACION      IN LC_TRANSFERENCIAS.NRO_OPERACION%TYPE
                                    ,P_NRO_CTA_REFERENCIA IN LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE
                                    ,
                                     -- P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                     P_DATO                IN NUMBER
                                    ,P_HORA                GE_MOVIMIENTOS.HORA%TYPE
                                    ,P_USUARIO             GE_MOVIMIENTOS.COD_USUARIO%TYPE
                                    ,P_FECHA               GE_MOVIMIENTOS.FECHA%TYPE
                                    ,P_TIPO_MOV            VARCHAR2
                                    ,P_COD_TRA_PADRE       GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                                    ,P_COD_TRANSACCION     GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                                    ,P_COD_GRU_TRANSACCION GE_AST_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE
                                    ,P_COD_BANCO           GE_BANCOS.COD_BANCO%type
                                    ,P_MONTO               GE_MOVIMIENTOS.MONTO%TYPE) RETURN VARCHAR2 IS
      V_NRO_CUENTA              LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE /* :=''*/
      ;
      V_ORIGINADOR              LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/
      ;
      V_BAN_ORIGINADOR          LC_TRANSFERENCIAS.NOM_BANCO%TYPE /* :=''*/
      ;
      V_BAN_INTERMEDIARIO       LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/
      ;
      V_BAN_BENEFICIARIO        LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/
      ;
      V_NOM_BENEFICIARIO        LC_TRANSFERENCIAS.NOM_BENEFICIARIO%TYPE /*:=''*/
      ;
      V_COD_PAI_BANCO           GE_AST_PAISES.COD_AST_PAIS%TYPE;
      V_COD_PAI_DESTINO         GE_AST_PAISES.COD_AST_PAIS%TYPE;
      V_BAN_INTERMEDIARIO_CORTO VARCHAR2(8);
   BEGIN

      --para hacer más veloz se utilizaría el CASE
      CASE
         WHEN P_COD_GRU_TRANSACCION = 'TRASFI-E' THEN
            -- Transferencias emitidas

            BEGIN
               SELECT TRAN.NOM_SOLICITANTE
                     ,PAI_PSA.FU_OBT_DES_BANCO(7, 'N')
                     ,PAI_PSA.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL, 'N')
                     ,TRAN.NOM_BANCO
                     ,TRAN.NOM_BENEFICIARIO
                     ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1)
                     , --PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL,NULL,1),
                      PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, COD_PAI_BANCO)
                     ,PAI_PSA.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL, 'S')
                 INTO V_ORIGINADOR
                     ,V_BAN_ORIGINADOR
                     ,V_BAN_INTERMEDIARIO
                     ,V_BAN_BENEFICIARIO
                     ,V_NOM_BENEFICIARIO
                     ,V_COD_PAI_BANCO
                     ,V_COD_PAI_DESTINO
                     ,V_BAN_INTERMEDIARIO_CORTO
                 FROM LC_TRANSFERENCIAS TRAN
                WHERE TRAN.NRO_OPERACION = P_NRO_OPERACION;
               --AND TRAN.COD_TIP_REFERENCIA = 12;
            EXCEPTION
               when no_data_found then
                  V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                         'P')); --'N.A.';
                  V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.';
                  V_BAN_BENEFICIARIO        := 'N.A.';
                  V_NOM_BENEFICIARIO        := 'N.A.';
                  V_BAN_INTERMEDIARIO       := 'N.A.'; --PAI_PSA.FU_OBT_DES_BANCO(7,'N');
                  V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                  V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                  V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);

               WHEN OTHERS THEN
                  V_NOM_BENEFICIARIO := SQLERRM;
            END;

         WHEN P_COD_GRU_TRANSACCION = 'TRASFI-I' THEN
            -- Transferencias recibidas

            BEGIN
               SELECT TRAN.NOM_SOLICITANTE V_ORIGINADOR
                     ,TRAN.NOM_BANCO V_BAN_ORIGINADOR
                     ,PAI_PSA.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL, 'N') V_BAN_INTERMEDIARIO
                     ,PAI_PSA.FU_OBT_DES_BANCO(7, 'N') V_BAN_BENEFICIARIO
                     ,TRAN.NOM_BENEFICIARIO V_NOM_BENEFICIARIO
                     ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, COD_PAI_BANCO) V_COD_PAI_BANCO
                     ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1) V_COD_PAI_DESTINO
                     ,PAI_PSA.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL, 'S') V_BAN_INTERMEDIARIO_CORTO
                 INTO V_ORIGINADOR
                     ,V_BAN_ORIGINADOR
                     ,V_BAN_INTERMEDIARIO
                     ,V_BAN_BENEFICIARIO
                     ,V_NOM_BENEFICIARIO
                     ,V_COD_PAI_BANCO
                     ,V_COD_PAI_DESTINO
                     ,V_BAN_INTERMEDIARIO_CORTO
                 FROM LC_TRANSFERENCIAS TRAN
                WHERE TRAN.NRO_OPERACION = P_NRO_OPERACION;
               --AND TRAN.COD_TIP_REFERENCIA = '00';
               --AND TRAN.NRO_CTA_REFERENCIA = P_NRO_CTA_REFERENCIA;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  V_ORIGINADOR              := 'N.A.';
                  V_BAN_ORIGINADOR          := 'N.A.';
                  V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.';
                  V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                         'P')); --'N.A.';
                  V_BAN_INTERMEDIARIO       := 'N.A.'; --PAI_PSA.FU_OBT_DES_BANCO(7,'N');
                  V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                  V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                  V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
               WHEN OTHERS THEN
                  NULL;
            END;

         WHEN P_COD_GRU_TRANSACCION in ('TRASFN-E', 'TRASFN-I') THEN
            --para los que son transferencia SNP

            IF P_TIPO_MOV = 'C' THEN
               BEGIN
                  --Para las transferencias de recepción--(ingreso)
                  Select NVL(GST.NOM_SOLICITANTE, 'N.A.') V_ORIGINADOR
                        ,PAI_PSA.FU_OBT_DES_BAN_SNP(GST.NRO_CTA_PTE_SOLICITANTE) V_BAN_ORIGINADOR
                        ,PAI_PSA.FU_OBT_DES_BANCO(1, 'N') V_BAN_INTERMEDIARIO
                        ,PAI_PSA.FU_OBT_DES_BANCO(7, 'N') V_BAN_BENEFICIARIO
                        ,NVL(GST.NOM_BENEFICIARIO, 'N.A.') V_NOM_BENEFICIARIO
                        ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1) V_COD_PAI_BANCO
                        ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1) V_COD_PAI_DESTINO
                        ,'BCP' V_BAN_INTERMEDIARIO_CORTO

                    INTO V_ORIGINADOR
                        ,V_BAN_ORIGINADOR
                        ,V_BAN_INTERMEDIARIO
                        ,V_BAN_BENEFICIARIO
                        ,V_NOM_BENEFICIARIO
                        ,V_COD_PAI_BANCO
                        ,V_COD_PAI_DESTINO
                        ,V_BAN_INTERMEDIARIO_CORTO
                    from ge_snp_transferencias GST
                   where GST.fecha = P_FECHA
                     and GST.cod_usuario = P_USUARIO
                     and GST.hora = P_HORA
                     and GST.FEC_RECEPCION IS NOT NULL; --condición para los ingresos(recepción)
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     V_ORIGINADOR              := 'N.A.'; --'TRANSF. G.U.I.';
                     V_BAN_ORIGINADOR          := FU_OBT_NOM_BANCO_TRASFN(P_HORA, P_USUARIO, P_FECHA,
                                                                          P_NRO_CTA_REFERENCIA,
                                                                          P_TIPO_MOV, P_MONTO); --'N.A.';--'TRANSF. G.U.I.';
                     V_BAN_INTERMEDIARIO       := PAI_PSA.FU_OBT_DES_BANCO(1, 'N');
                     V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.';--'TRANSF. G.U.I.';
                     V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                            'P')); --'N.A.';--'TRANSF. G.U.I.';
                     V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                     V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                     V_BAN_INTERMEDIARIO_CORTO := 'BCP';
                  WHEN OTHERS THEN
                     V_ORIGINADOR := 'ERROR';
               END;
            END IF;

            IF P_TIPO_MOV = 'D' THEN
               BEGIN
                  --Para las transferencias de envio--(egreso)
                  Select NVL(GST.NOM_SOLICITANTE, 'N.A.') V_ORIGINADOR
                        ,PAI_PSA.FU_OBT_DES_BANCO(7, 'N') V_BAN_ORIGINADOR
                        ,PAI_PSA.FU_OBT_DES_BANCO(1, 'N') V_BAN_INTERMEDIARIO
                        ,PAI_PSA.FU_OBT_DES_BAN_SNP(GST.NRO_CTA_PTE_BENEFICIARIO) V_BAN_BENEFICIARIO
                        ,NVL(GST.NOM_BENEFICIARIO, 'N.A.') V_NOM_BENEFICIARIO
                        ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1) V_COD_PAI_BANCO
                        ,PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1) V_COD_PAI_DESTINO
                        ,'BCP' V_BAN_INTERMEDIARIO_CORTO

                    INTO V_ORIGINADOR
                        ,V_BAN_ORIGINADOR
                        ,V_BAN_INTERMEDIARIO
                        ,V_BAN_BENEFICIARIO
                        ,V_NOM_BENEFICIARIO
                        ,V_COD_PAI_BANCO
                        ,V_COD_PAI_DESTINO
                        ,V_BAN_INTERMEDIARIO_CORTO
                    from ge_snp_transferencias GST
                   where GST.fecha = P_FECHA
                     and GST.cod_usuario = P_USUARIO
                     and GST.hora = P_HORA
                     and GST.FEC_RECEPCION IS NULL; --condición para los EGRESOS(envio)
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     IF V_ORIGINADOR IS NULL THEN
                        V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                               'P')); --'N.A.';--'TRANSF. G.U.I.';
                        V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.';--'TRANSF. G.U.I.';
                        V_BAN_INTERMEDIARIO       := PAI_PSA.FU_OBT_DES_BANCO(1, 'N');
                        V_BAN_BENEFICIARIO        := FU_OBT_NOM_BANCO_TRASFN(P_HORA, P_USUARIO,
                                                                             P_FECHA,
                                                                             P_NRO_CTA_REFERENCIA,
                                                                             P_TIPO_MOV, P_MONTO); --'N.A.';--'TRANSF. G.U.I.';
                        V_NOM_BENEFICIARIO        := 'N.A.'; --'TRANSF. G.U.I.';
                        V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                        V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
                        V_BAN_INTERMEDIARIO_CORTO := 'BCP';
                     END IF;

                  WHEN OTHERS THEN
                     V_ORIGINADOR := 'ERROR';
               END;
            END IF;
         WHEN P_COD_GRU_TRANSACCION = 'CHEQ-I' AND P_TIPO_MOV = 'C' THEN
            V_BAN_BENEFICIARIO  := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --BBVAPY siempre
            V_NOM_BENEFICIARIO  := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                             'P'));
            V_COD_PAI_BANCO     := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
            V_COD_PAI_DESTINO   := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
            V_BAN_INTERMEDIARIO := 'N.A.';
            V_ORIGINADOR        := 'N.A.';
            /*¿Cargo otros Bancos (plaza Local)------------- transacción padre (352)

            ¿Cargo otros Bancos (plaza Extranjera)-------- transacción padre (136) transacción Hijo (633)
            ¿Cargo otros Bancos (plaza Extranjera)-------- transacción padre (560) transacción Hijo (560)

            ¿Cargo nuestro Banco ------------------------- transacción padre (351) transacción Hijo (606)
            ¿Cargo nuestro Banco ------------------------- transacción padre (394) */

            IF P_COD_TRA_PADRE IN (352, 395, 372) /*AND P_COD_TRANSACCION = 607*/
             THEN
               V_BAN_ORIGINADOR := 'BANCO PLAZA LOCAL';
            ELSIF (P_COD_TRA_PADRE = 136 AND P_COD_TRANSACCION = 633) OR
                  (P_COD_TRA_PADRE = 560 AND P_COD_TRANSACCION = 560) THEN
               V_BAN_ORIGINADOR := 'BANCO PLAZA EXTRANJERA';
            ELSIF (P_COD_TRA_PADRE IN (351, 371) AND P_COD_TRANSACCION = 606) OR
                  (P_COD_TRA_PADRE = 394) THEN
               V_BAN_ORIGINADOR := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --BBVAPY siempre
            ELSE
               V_BAN_ORIGINADOR := 'OTROS BANCOS';
            END IF;
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
         WHEN P_COD_GRU_TRANSACCION = 'CHEQ-E' AND P_TIPO_MOV = 'D' THEN
            --en caso de no tener cod_banco se despliega banco BBVA y su principal de cta.
            IF P_COD_BANCO IS NULL THEN
               V_BAN_BENEFICIARIO := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            ELSE
               V_BAN_BENEFICIARIO := PAI_PSA.FU_OBT_DES_BANCO(P_COD_BANCO, 'N');
            END IF;

            V_NOM_BENEFICIARIO := 'N.A.';

            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --BBVAPY siempre
         WHEN P_COD_GRU_TRANSACCION = 'ATM-E' THEN
            --EGRESO
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := 'N.A.';
            V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
         WHEN P_COD_GRU_TRANSACCION = 'EFECT-E' THEN
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := 'N.A.';
            V_NOM_BENEFICIARIO        := 'N.A.';
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
         WHEN P_COD_GRU_TRANSACCION = 'PRESTA-I' THEN
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.'  ;
            V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P')); --'N.A.'  ;
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';

         WHEN P_COD_GRU_TRANSACCION = 'OTROS-E' THEN
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N'); --'N.A.';
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := 'N.A.';
            V_NOM_BENEFICIARIO        := 'N.A.';
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';

         WHEN P_COD_GRU_TRANSACCION = 'TRNINT-E' THEN
            V_ORIGINADOR              := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_NOM_BENEFICIARIO        := FU_OBT_NOM_PERSONA_TRNINT(P_HORA, P_USUARIO, P_FECHA,
                                                                   P_NRO_CTA_REFERENCIA, P_TIPO_MOV,
                                                                   P_MONTO, P_COD_TRA_PADRE,
                                                                   P_COD_TRANSACCION); --'N.A.'  ;
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';

         WHEN P_COD_GRU_TRANSACCION = 'TRNINT-I' THEN
            V_ORIGINADOR              := FU_OBT_NOM_PERSONA_TRNINT(P_HORA, P_USUARIO, P_FECHA,
                                                                   P_NRO_CTA_REFERENCIA, P_TIPO_MOV,
                                                                   P_MONTO, P_COD_TRA_PADRE,
                                                                   P_COD_TRANSACCION); --'N.A.'  ;
            V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_BAN_INTERMEDIARIO       := 'N.A.';
            V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
            V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                   'P'));
            V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1);
            V_BAN_INTERMEDIARIO_CORTO := 'N.A.';

         WHEN P_COD_GRU_TRANSACCION IN ('EFECT-I', 'PRESTA-E', 'OTROS-I') THEN

            IF P_TIPO_MOV = 'C' THEN
               --crédito a cuenta
               V_BAN_BENEFICIARIO        := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
               V_NOM_BENEFICIARIO        := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,
                                                                                      'P'));
               V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
               V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
               V_BAN_INTERMEDIARIO       := 'N.A.';
               V_ORIGINADOR              := 'N.A.';
               V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
               V_BAN_ORIGINADOR          := 'N.A.'; --PAI_PSA.FU_OBT_DES_BANCO(7,'N');
            ELSE
               --débito a cuenta
               V_BAN_BENEFICIARIO        := 'N.A.';
               V_BAN_ORIGINADOR          := PAI_PSA.FU_OBT_DES_BANCO(7, 'N');
               V_NOM_BENEFICIARIO        := 'N.A.';
               V_COD_PAI_BANCO           := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
               V_COD_PAI_DESTINO         := PAI_PSA.FU_OBT_COD_ISO_PAIS(NULL, NULL, 1); --Cod Paraguay
               V_BAN_INTERMEDIARIO       := 'N.A.';
               V_ORIGINADOR              := 'N.A.';
               V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
            END IF;

         ELSE
            NULL;
      END CASE;

      --
      CASE
         WHEN P_DATO = 1 THEN
            RETURN V_NRO_CUENTA;
         WHEN P_DATO = 2 THEN
            RETURN V_ORIGINADOR;
         WHEN P_DATO = 3 THEN
            RETURN V_BAN_ORIGINADOR;
         WHEN P_DATO = 4 THEN
            RETURN V_BAN_INTERMEDIARIO;
         WHEN P_DATO = 5 THEN
            RETURN V_BAN_BENEFICIARIO;
         WHEN P_DATO = 6 THEN
            RETURN V_NOM_BENEFICIARIO;
         WHEN P_DATO = 7 THEN
            RETURN V_COD_PAI_BANCO;
         WHEN P_DATO = 8 THEN
            RETURN V_COD_PAI_DESTINO;
         WHEN P_DATO = 9 THEN
            RETURN V_BAN_INTERMEDIARIO_CORTO;
         ELSE
            RETURN ' ';
      END CASE;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'ERROR';
   END;
   --Función que retorna el nro de tipo de Canal de la transacción
   FUNCTION FU_OBT_NUM_CANAL_TRANSACCION(P_COD_USUARIO BA_USUARIOS.COD_USUARIO%TYPE) RETURN NUMBER IS
      V_NRO_CANAL NUMBER(2);
   BEGIN
      --1-VENTANILLA
      --2-ATM
      --3-AUTOSERVICIO
      --4-SISTEMA

      IF substr(P_COD_USUARIO, 1, 3) = 'ATM' THEN
         RETURN 2;
      END IF;

      BEGIN
         select 1
           INTO V_NRO_CANAL
           FROM CJ_CAJAS T
          WHERE T.COD_USUARIO = P_COD_USUARIO
            AND T.TIPO = 'H'; --humano
         return V_NRO_CANAL;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      IF V_NRO_CANAL IS NULL THEN
         BEGIN
            select 2
              INTO V_NRO_CANAL
              FROM CJ_CAJAS T
             WHERE T.COD_USUARIO = P_COD_USUARIO
               AND T.TIPO = 'A'; --atm
            return V_NRO_CANAL;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;

      IF V_NRO_CANAL IS NULL THEN
         BEGIN
            select 3
              INTO V_NRO_CANAL
              FROM CJ_CAJAS T
             WHERE T.COD_USUARIO = P_COD_USUARIO
               AND T.TIPO = 'S'; --autoservicio
            return V_NRO_CANAL;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN 4;
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;

   --Función que retorna el BENEFICIARIO/ORIGINADOR en trasnacciones internas assist
   FUNCTION FU_OBT_NOM_PERSONA_TRNINT(P_HORA            GE_MOVIMIENTOS.HORA%TYPE
                                     ,P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE
                                     ,P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE
                                     ,P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE
                                     ,P_TIPO_MOV        VARCHAR2
                                     ,P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE
                                     ,P_COD_TRA_PADRE   GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                                     ,P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
      RETURN VARCHAR2 IS
      V_NOMBRE BA_PERSONAS.NOM_COMPLETO%TYPE;
      --  V_CONTROL VARCHAR2(2000);
   BEGIN

      IF V_REPROCESO = 'S' THEN
         IF P_TIPO_MOV = 'C' THEN
            --buscar el originador en caso de ser por HBANK
            IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO, 1, 3) = 'ATM')) THEN

               BEGIN
                  Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                    INTO V_NOMBRE
                    from gv_movimientos_ast t
                   where t.FECHA = P_FECHA
                     and t.HORA = P_HORA
                     and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                     and T.COD_TIP_MOVIMIENTO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                     and t.COD_USUARIO = P_USUARIO
                     AND T.MONTO = P_MONTO_TR
                     AND EXISTS
                   (SELECT 1
                            FROM GE_AST_TRANSACCIONES TR
                           WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                             AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                             AND TR.COD_MODULO = T.COD_MODULO
                             AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     V_NOMBRE := 'N.A.';
                  WHEN OTHERS THEN
                     V_NOMBRE := SQLERRM;
               END;

            ELSE

               --PARA BUSCAR EL ORIGINADOR DE PAGOS DE NÓMINA y otros (transferencias por ITGF
               IF P_COD_TRA_PADRE IN (303, 309, 346, 329) AND P_COD_TRANSACCION = 602 THEN
                  --329 cda
                  BEGIN
                     Select DISTINCT FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                       INTO V_NOMBRE
                       from gv_movimientos_ast t
                      where t.FECHA = P_FECHA
                        and t.HORA = P_HORA
                        and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                        and T.COD_TIP_MOVIMIENTO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                        and t.COD_USUARIO = P_USUARIO
                           --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                           --PARA PAGOS DE NÓMINA--------
                        and t.COD_TRA_PADRE = P_COD_TRA_PADRE --303 --
                           -- and   t.COD_MOD_PADRE = 3   --
                           -- and   t.COD_MAD_PADRE = 31  --
                        and t.COD_TRANSACCION = 503 --P_COD_TRANSACCION--503
                           ------------------------------
                        AND EXISTS
                      (SELECT 1
                               FROM GE_AST_TRANSACCIONES TR
                              WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                                AND TR.COD_MODULO = T.COD_MODULO
                                AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
                  EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                        V_NOMBRE := 'N.A.';
                     WHEN TOO_MANY_ROWS THEN
                        V_NOMBRE := 'VARIOS ORIGINADORES*N';
                     WHEN OTHERS THEN
                        V_NOMBRE := SQLERRM;
                  END;

               END IF;

            END IF;

            --MOVIMIENTOS DÉBITO--BUSCAR BENEFICIARIO
         ELSE
            --buscar el BENEFICIARIO en caso de ser por HBANK
            IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO, 1, 3) = 'ATM')) THEN
               BEGIN
                  Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                    INTO V_NOMBRE
                    from gv_movimientos_ast t
                   where t.FECHA = P_FECHA
                     and t.HORA = P_HORA
                     and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (CRÉDITO)
                     and T.COD_TIP_MOVIMIENTO != P_TIPO_MOV --condición para encontrar el otro movimiento (CRÉDITO)
                     and t.COD_USUARIO = P_USUARIO
                     AND T.MONTO = P_MONTO_TR
                     AND EXISTS
                   (SELECT 1
                            FROM GE_AST_TRANSACCIONES TR
                           WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                             AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                             AND TR.COD_MODULO = T.COD_MODULO
                             AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     V_NOMBRE := 'N.A.';
                  WHEN TOO_MANY_ROWS THEN
                     V_NOMBRE := 'VARIOS BENEFICIARIOS*';
                  WHEN OTHERS THEN

                     V_NOMBRE := SQLERRM;
               END;

            ELSE

               --PARA BUSCAR EL BENEFICIARIO DE PAGOS DE NÓMINA  Y otros (transferencias por ITGF)
               IF P_COD_TRA_PADRE IN (303, 309, 346, 329) AND P_COD_TRANSACCION = 503 THEN
                  BEGIN
                     Select DISTINCT DECODE(t.COD_MODALIDAD, '45', t.DENOMINACION,
                                            FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,
                                                                                       'P')))
                       INTO V_NOMBRE
                       from gv_movimientos_ast t
                      where t.FECHA = P_FECHA
                        and t.HORA = P_HORA
                        and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                        and T.COD_TIP_MOVIMIENTO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                        and t.COD_USUARIO = P_USUARIO
                           --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                           --PARA PAGOS DE NÓMINA--------
                        and t.COD_TRA_PADRE = P_COD_TRA_PADRE --303 --
                           -- and   t.COD_MOD_PADRE = 3   --
                           -- and   t.COD_MAD_PADRE = 31  --
                        and t.COD_TRANSACCION = 602 --P_COD_TRANSACCION--503
                           ------------------------------
                        AND EXISTS
                      (SELECT 1
                               FROM GE_AST_TRANSACCIONES TR
                              WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                                AND TR.COD_MODULO = T.COD_MODULO
                                AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
                  EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                        IF P_COD_TRA_PADRE != 346 THEN
                           V_NOMBRE := 'N.A.*';
                        ELSE
                           V_NOMBRE := 'PAGO A PROVEEDOR';
                        END IF;

                     WHEN TOO_MANY_ROWS THEN
                        IF P_COD_TRA_PADRE != 346 THEN
                           V_NOMBRE := 'VARIOS BENEFICIARIOS-PAGOS DE NÓMINA';
                        ELSE
                           V_NOMBRE := 'VARIOS BENEFICIARIOS-PAGOS A PROVEEDORES';
                        END IF;
                     WHEN OTHERS THEN
                        V_NOMBRE := SQLERRM;
                  END;

               END IF;

            END IF;
         END IF;

      ELSE
         --PARA LOS MOVIMIENTOS DEL DÍA.
         IF P_TIPO_MOV = 'C' THEN
            --buscar el originador en caso de ser por HBANK
            IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO, 1, 3) = 'ATM')) THEN

               BEGIN
                  Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                    INTO V_NOMBRE
                    from ge_movimientos   t
                        ,GE_TRANSACCIONES TR
                   where t.FECHA = P_FECHA
                     and t.HORA = P_HORA
                     and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                     and TR.TIPO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                     and t.COD_USUARIO = P_USUARIO
                     AND T.MONTO = P_MONTO_TR

                     AND T.COD_MODULO = TR.COD_MODULO
                     AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                     AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                     AND T.COD_MODULO = TR.COD_MODULO
                     AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                     AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                        --AH,CC y PR
                     AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                     AND (TR.cod_modulo in (3, 4, 6) OR
                         (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)))

                     AND EXISTS
                   (SELECT 1
                            FROM GE_AST_TRANSACCIONES TR
                           WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                             AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                             AND TR.COD_MODULO = T.COD_MODULO
                             AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     V_NOMBRE := 'N.A.';
                  WHEN OTHERS THEN
                     V_NOMBRE := SQLERRM;
               END;

            ELSE

               --PARA BUSCAR EL ORIGINADOR DE PAGOS DE NÓMINA y otros (transferencias por ITGF
               IF P_COD_TRA_PADRE IN (303, 309, 346, 329) AND P_COD_TRANSACCION = 602 THEN
                  --329 cda
                  BEGIN
                     Select DISTINCT FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                       INTO V_NOMBRE
                       from ge_movimientos   t
                           ,GE_TRANSACCIONES TR
                      where t.FECHA = P_FECHA
                        and t.HORA = P_HORA
                        and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                        and TR.TIPO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                        and t.COD_USUARIO = P_USUARIO
                           --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                           --PARA PAGOS DE NÓMINA--------
                        and t.COD_TRA_PADRE = P_COD_TRA_PADRE --303 --
                           -- and   t.COD_MOD_PADRE = 3   --
                           -- and   t.COD_MAD_PADRE = 31  --
                        and t.COD_TRANSACCION = 503 --P_COD_TRANSACCION--503
                           ------------------------------
                        AND T.COD_MODULO = TR.COD_MODULO
                        AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                        AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                           --AH,CC y PR
                        AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                        AND (TR.cod_modulo in (3, 4, 6) OR
                            (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)))

                        AND EXISTS
                      (SELECT 1
                               FROM GE_AST_TRANSACCIONES TR
                              WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                                AND TR.COD_MODULO = T.COD_MODULO
                                AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
                  EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                        V_NOMBRE := 'N.A.';
                     WHEN TOO_MANY_ROWS THEN
                        V_NOMBRE := 'VARIOS ORIGINADORES*N';
                     WHEN OTHERS THEN
                        V_NOMBRE := SQLERRM;
                  END;

               END IF;

            END IF;

            --MOVIMIENTOS DÉBITO--BUSCAR BENEFICIARIO
         ELSE
            --buscar el BENEFICIARIO en caso de ser por HBANK
            IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO, 1, 3) = 'ATM')) THEN
               BEGIN
                  Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P'))
                    INTO V_NOMBRE
                    from ge_movimientos   t
                        ,GE_TRANSACCIONES TR
                   where t.FECHA = P_FECHA
                     and t.HORA = P_HORA
                     and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (CRÉDITO)
                     and TR.tipo != P_TIPO_MOV --condición para encontrar el otro movimiento (CRÉDITO)
                     and t.COD_USUARIO = P_USUARIO
                     AND T.MONTO = P_MONTO_TR
                     AND T.COD_MODULO = TR.COD_MODULO
                     AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                     AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                        --AH,CC y PR
                     AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                     AND (TR.cod_modulo in (3, 4, 6) OR
                         (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)))
                     AND EXISTS
                   (SELECT 1
                            FROM GE_AST_TRANSACCIONES TR
                           WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                             AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                             AND TR.COD_MODULO = T.COD_MODULO
                             AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     V_NOMBRE := 'N.A.';
                  WHEN TOO_MANY_ROWS THEN
                     V_NOMBRE := 'VARIOS BENEFICIARIOS*';
                  WHEN OTHERS THEN

                     V_NOMBRE := SQLERRM;
               END;

            ELSE

               --PARA BUSCAR EL BENEFICIARIO DE PAGOS DE NÓMINA  Y otros (transferencias por ITGF)
               IF P_COD_TRA_PADRE IN (303, 309, 346, 329) AND P_COD_TRANSACCION = 503 THEN
                  BEGIN
                     Select DISTINCT DECODE(t.COD_MODALIDAD, '45', CU.DENOMINACION,
                                            FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,
                                                                                       'P')))
                       INTO V_NOMBRE
                       from ge_movimientos   t
                           ,GE_TRANSACCIONES TR
                           ,GE_CUENTAS       CU
                      where t.FECHA = P_FECHA
                        and t.HORA = P_HORA
                        and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                        and TR.tipo != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
                        and t.COD_USUARIO = P_USUARIO
                           --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                           --PARA PAGOS DE NÓMINA--------
                        and t.COD_TRA_PADRE = P_COD_TRA_PADRE --303 --
                           -- and   t.COD_MOD_PADRE = 3   --
                           -- and   t.COD_MAD_PADRE = 31  --
                        and t.COD_TRANSACCION = 602 --P_COD_TRANSACCION--503
                           ------------------------------
                        AND t.NRO_CUENTA = CU.NRO_CUENTA
                        AND T.COD_MODULO = TR.COD_MODULO
                        AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                        AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                           --AH,CC y PR
                        AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                        AND (TR.cod_modulo in (3, 4, 6) OR
                            (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)))
                        AND EXISTS
                      (SELECT 1
                               FROM GE_AST_TRANSACCIONES TR
                              WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                AND TR.COD_MODALIDAD = T.COD_MODALIDAD
                                AND TR.COD_MODULO = T.COD_MODULO
                                AND TR.COD_GRU_TRANSACCION IN ('TRNINT-I', 'TRNINT-E'));
                  EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                        IF P_COD_TRA_PADRE != 346 THEN
                           V_NOMBRE := 'N.A.*';
                        ELSE
                           V_NOMBRE := 'PAGO A PROVEEDOR';
                        END IF;

                     WHEN TOO_MANY_ROWS THEN
                        IF P_COD_TRA_PADRE != 346 THEN
                           V_NOMBRE := 'VARIOS BENEFICIARIOS-PAGOS DE NÓMINA';
                        ELSE
                           V_NOMBRE := 'VARIOS BENEFICIARIOS-PAGOS A PROVEEDORES';
                        END IF;
                     WHEN OTHERS THEN
                        V_NOMBRE := SQLERRM;
                  END;

               END IF;

            END IF;
         END IF;
      END IF;
      RETURN V_NOMBRE;
   END;

   --CONTROL DE DEVOLUCIÓN DE CHEQUES (S/N)
   FUNCTION FU_OBT_IND_CHEQ_DEVUELTO(P_NRO_DOCUMENTO   GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
                                    ,P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE
                                    ,P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE
                                    ,P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE
                                    ,P_TIPO_MOV        VARCHAR2
                                    ,P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE) RETURN VARCHAR2 IS
      V_IND VARCHAR2(2) := '';

   BEGIN

      IF V_REPROCESO = 'S' THEN
         --busca el movimiento de devolución de acuerdo al nro de documento
         BEGIN
            Select 'S'
              INTO V_IND
              from GV_MOVIMIENTOS_AST t
             where T.FECHA = P_FECHA
                  --AND   T.HORA = '18:44:12'
               and t.NRO_CUENTA = P_NRO_CTA_CLIENTE
               and t.NRO_DOCUMENTO = P_NRO_DOCUMENTO --<--
               AND T.COD_USUARIO = P_USUARIO
               AND T.COD_TIP_MOVIMIENTO != P_TIPO_MOV
               and t.monto = P_MONTO_TR;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               V_IND := 'N';
            WHEN OTHERS THEN
               V_IND := 'N';
         END;
      ELSE
         --busca el movimiento de devolución de acuerdo al nro de documento
         BEGIN
            Select 'S'
              INTO V_IND
              from GE_MOVIMIENTOS   t
                  ,GE_TRANSACCIONES TR
             where T.FECHA = P_FECHA
                  --AND   T.HORA = '18:44:12'
               and t.NRO_CUENTA = P_NRO_CTA_CLIENTE
               and t.NRO_DOCUMENTO = P_NRO_DOCUMENTO --<--
               AND T.COD_USUARIO = P_USUARIO
               AND TR.TIPO != P_TIPO_MOV
               and t.monto = P_MONTO_TR

               AND T.COD_MODULO = TR.COD_MODULO
               AND T.COD_MODALIDAD = TR.COD_MODALIDAD
               AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                  --AH,CC y PR
               AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
               AND (TR.cod_modulo in (3, 4, 6) OR
                   (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)));
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               V_IND := 'N';
            WHEN OTHERS THEN
               V_IND := 'N';
         END;
      END IF;

      RETURN V_IND;
   END;
   --Función que retorna el BANCO BENEFICIARIO/ORIGINADOR en trasnacciones Nacionales(TRASFN-I/E) assist
   FUNCTION FU_OBT_NOM_BANCO_TRASFN(P_HORA            GE_MOVIMIENTOS.HORA%TYPE
                                   ,P_USUARIO         GE_MOVIMIENTOS.COD_USUARIO%TYPE
                                   ,P_FECHA           GE_MOVIMIENTOS.FECHA%TYPE
                                   ,P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE
                                   ,P_TIPO_MOV        VARCHAR2
                                   ,P_MONTO_TR        GE_MOVIMIENTOS.MONTO%TYPE)
   -- P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
      --P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
    RETURN VARCHAR2 IS
      V_NOMBRE BA_PERSONAS.NOM_COMPLETO%TYPE;
      -- V_CONTROL VARCHAR2(2000);
   BEGIN

      IF V_REPROCESO = 'S' THEN
         BEGIN
            Select DISTINCT DECODE(T.COD_MODALIDAD, '455', T.DENOMINACION,
                                   FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P')))
              INTO V_NOMBRE
              from gv_movimientos_ast t
             where t.FECHA = P_FECHA
               and t.HORA = P_HORA
               and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
               and T.COD_TIP_MOVIMIENTO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
               and t.COD_USUARIO = P_USUARIO
               AND T.MONTO = P_MONTO_TR /*
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       AND   TR.COD_MODULO = T.COD_MODULO
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'))*/
            ;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               V_NOMBRE := 'N.A.';
            WHEN OTHERS THEN
               V_NOMBRE := SQLERRM;
         END;
      ELSE
         --MOVIMIENTO DEL DÍA.
         BEGIN
            Select DISTINCT DECODE(T.COD_MODALIDAD, '455', CU.DENOMINACION,
                                   FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA, 'P')))
              INTO V_NOMBRE
              from ge_movimientos   t
                  ,GE_TRANSACCIONES TR
                  ,GE_CUENTAS       CU
             where t.FECHA = P_FECHA
               and t.HORA = P_HORA
               and t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
               and TR.TIPO != P_TIPO_MOV --condición para encontrar el otro movimiento (DEBITO)
               and t.COD_USUARIO = P_USUARIO
               AND T.MONTO = P_MONTO_TR

               AND t.NRO_CUENTA = CU.NRO_CUENTA
               AND T.COD_MODULO = TR.COD_MODULO
               AND T.COD_MODALIDAD = TR.COD_MODALIDAD
               AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                  --AH,CC y PR
               AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
               AND (TR.cod_modulo in (3, 4, 6) OR
                   (TR.cod_modulo = 9 AND T.cod_mod_padre in (3, 4, 6)))
            /*
            AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                AND   TR.COD_MODULO = T.COD_MODULO
                                                                AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'))*/
            ;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               V_NOMBRE := 'N.A.';
            WHEN OTHERS THEN
               V_NOMBRE := SQLERRM;
         END;

      END IF;

      RETURN V_NOMBRE;
   END;

   -- Verifica si ya se proceso en la fecha
   FUNCTION FU_VER_FEC_PROCESO(P_FECHA DATE) RETURN BOOLEAN IS
      V_EXISTE NUMBER;
   BEGIN
      --
      SELECT DISTINCT 1
        INTO V_EXISTE
        FROM GE_CTA_IMP_PSAML A
       WHERE TRUNC(A.FEC_PROCESO) = TRUNC(P_FECHA);
      --
      IF V_EXISTE = 1 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
      --
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000, 'Error al verificar la fecha de proceso.' || sqlerrm);
   END;

   -- Verifica si el cliente es principal de alguna cuenta
   FUNCTION FU_VER_CLI_PRINCIPAL(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
      V_PRINCIPAL VARCHAR2(1);
   BEGIN
      --
      BEGIN
         SELECT DISTINCT 'S'
           INTO V_PRINCIPAL
           FROM GE_CTA_CLIENTES  A
               ,GE_CTA_IMP_PSAML B
          WHERE A.NRO_CUENTA = B.NRO_CUENTA
            AND A.COD_PERSONA = B.COD_PERSONA
            AND A.COD_PERSONA = P_COD_PERSONA
            AND A.RELACION = 'P'
            AND A.COD_MODULO IN (3, 4, 6);

         RETURN V_PRINCIPAL;
         --
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RETURN 'N';
         WHEN OTHERS THEN
            RETURN 'N';
      END;
      --
   END;

   FUNCTION FU_OBT_NRO_CANAL(P_COD_TRA_PADRE  GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
                            ,P_COD_USUARIO    GE_MOVIMIENTOS.COD_USUARIO%TYPE
                            --,P_COD_PERSONA    GE_MOVIMIENTOS.COD_PERSONA%TYPE
                            ,P_NRO_DOCUMENTO  GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
                            ,P_NRO_DOCUMENTO2 GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
                            ,P_NRO_DOCUMENTO3 GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
                            ,P_NRO_CUENTA     GE_MOVIMIENTOS.NRO_CUENTA%TYPE
                            ,P_FEC_INSERCION  GE_MOVIMIENTOS.FEC_INSERCION%TYPE) RETURN NUMBER IS
      V_COD_CANAL     NUMBER := 999;
      --V_NRO_CAJA      GE_MOVIMIENTOS.NRO_CAJA%TYPE;
      V_NRO_DOCUMENTO BW_PAG_SERVICIOS.NRO_DOCUMENTO%TYPE;

   BEGIN
      BEGIN
         IF P_COD_USUARIO LIKE 'ATM%' THEN
            IF p_cod_tra_padre <> 488 then
               if nvl(p_nro_documento2, 0) <> 0 then
                  v_cod_canal := 66; -- ntro u otros cajeros.
               else
                  v_cod_canal := 140; -- pago a comercios por mensajeria.
               end if;
            else
               begin
                  select nro_documento
                    into v_nro_documento
                    from bw_pag_servicios
                   where nro_transaccion = to_char(p_nro_documento3);
               exception
                  when others then
                     v_nro_documento := 0;
               end;

               if v_nro_documento <> 0 then
                  -- pagos de servicios de la web
                  begin
                     select decode(nro_caja, 994, 139, 140)
                       into v_cod_canal
                       from bw_movimientos
                      where trunc(fec_insercion) = trunc(p_fec_insercion)
                        and nro_cuenta = p_nro_cuenta
                        and nro_documento = p_nro_documento;
                  exception
                     when others then
                        v_cod_canal := 66;
                  end;
               end if;
            end if;
         ELSIF P_COD_USUARIO LIKE 'HBANK%' THEN
            if p_cod_tra_padre = 487 then
               -- pago de la set
               begin
                  select decode(cod_canal, 30, 140, 29, 139, 0)
                    into v_cod_canal
                    from ge_set_pagos
                   where nro_operacion = p_nro_documento;
               exception
                  when others then
                     v_cod_canal := 0;
               end;

               if v_cod_canal = 0 then
                  begin
                     select decode(nro_caja, 994, 139, 140)
                       into v_cod_canal
                       from bw_movimientos
                      where trunc(fec_insercion) = trunc(p_fec_insercion)
                        and nro_documento = p_nro_documento
                        and nro_cuenta = p_nro_cuenta;
                  exception
                     when others then
                        v_cod_canal := 66;
                  end;
               end if;
            else
               begin
                  select decode(nro_caja, 994, 139, 140)
                    into v_cod_canal
                    from bw_movimientos
                   where trunc(fec_insercion) = trunc(p_fec_insercion)
                     and nro_documento = p_nro_documento
                     and nro_cuenta = p_nro_cuenta;
               exception
                  when others then
                     v_cod_canal := 66;
               end;
            end if;
         ELSE
            v_cod_canal := 999; -- Red Nacional de Oficinas
         END IF;
      END;
      return v_cod_canal;
   END;


   FUNCTION FU_OBT_NRO_SUB_OPERACION(P_COD_PERSONA IN VARCHAR2,
                                     P_NRO_CUENTA IN VARCHAR2)RETURN NUMBER
   IS
      V_NRO_SUB_OPERACION NUMBER(5);
      --V_NRO_SUB_OPERACION_NEW NUMBER(5);
   BEGIN
      BEGIN
         SELECT A.NRO_SUB_CTA_BANTOTAL
         INTO V_NRO_SUB_OPERACION
         FROM MI_CTA_CLIENTES A
         WHERE A.COD_PERSONA = P_COD_PERSONA
         AND   A.NRO_CTA_ITGF = P_NRO_CUENTA;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            /*--se obtiene el nro máximo de nro sub operación
            begin
               select
               NVL(max(s.nro_sub_cta_bantotal)+1,1)
               INTO V_NRO_SUB_OPERACION_NEW
               from MI_CTA_CLIENTES s
               where s.cod_persona = p_cod_persona;
            exception
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000, 'Error al OBTENER nuevo nro de sub operación.' || sqlerrm);
            end;
            --se inserta el registro nuevo en la tabla mi_cta_clientes

            BEGIN
               INSERT INTO mi_cta_clientes
                            (cod_persona,
                             nro_cta_itgf,
                             nro_cta_bantotal,
                             nro_sub_cta_bantotal)
                             values
                            (p_cod_persona,
                             p_nro_cuenta,
                             0,
                             V_NRO_SUB_OPERACION_NEW);
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE_APPLICATION_ERROR(-20000, 'Error al crear nro sub operación bantotal.' || sqlerrm);
            END;
            V_NRO_SUB_OPERACION := V_NRO_SUB_OPERACION_NEW;*/
            RETURN 0;

         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Error al obtener nro sub operación bantotal.' || sqlerrm);
      END;

      RETURN V_NRO_SUB_OPERACION;
   END;


   FUNCTION FU_OBT_NRO_CTA_ITGF(P_NRO_CTA_BANTOTAL IN NUMBER, P_NRO_SUB_OPERACION IN NUMBER)RETURN VARCHAR2
   IS
      V_NRO_CUENTA GE_CUENTAS.nro_cuenta%TYPE;
   BEGIN
      begin
         select a.nro_Cta_itgf
         into v_nro_cuenta
         from MI_CTA_CLIENTES a
         where a.Nro_Cta_Bantotal = P_NRO_CTA_BANTOTAL
         and   a.nro_sub_cta_bantotal = P_NRO_SUB_OPERACION;
      exception
         when no_Data_found then
            --tool_pro_log_proceso(SYSDATE,p_cod_persona,P_NRO_SUB_OPERACION,'FU_OBT_NRO_CTA_ITGF');
            RAISE_APPLICATION_ERROR(-20000, 'No se encuentra la cta para los datos buscados');
         when others then
            RAISE_APPLICATION_ERROR(-20000, 'Error al obtener nro cta itgf.' || sqlerrm);
      end;
      return v_nro_cuenta;
   END;


   FUNCTION FU_CLI_EXI_ENBANTOTAL(P_COD_PAIS      IN VARCHAR2,
                                  P_TIP_DOCUMENTO IN VARCHAR2,
                                  P_NRO_DOCUMENTO IN VARCHAR2)
      RETURN VARCHAR2 IS
      V_EXISTE VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         select 'S'
           INTO V_EXISTE
           FROM FSD001 A
          WHERE A.PePAIS = P_COD_PAIS
            AND A.PETDOC = P_TIP_DOCUMENTO
            AND A.PENDOC = P_NRO_DOCUMENTO
            and rownum = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_EXISTE := 'N';
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,
                                    'Error al verificar si el cliente existe en Bantotal.' ||
                                    sqlerrm);
      END;
      RETURN V_EXISTE;
   END;

   FUNCTION FU_OBT_OFI_BANTOTAL(P_COD_OFICIAL IN VARCHAR2) RETURN NUMBER IS
      V_COD_OFICIAL    NUMBER(5);
      v_usu_supervisor varchar2(15);
   BEGIN
      /*
            SELECT FST010.EJCOD AS "CODIGO DE EJECUTIVO",
      FST010.EJNOM AS "NOMBRE DE EJECUTIVO",
      FST146.UBUSER AS "USUARIO DE WINDOWS"
      FROM BANTOTALDB.FST010 AS FST010, BANTOTALDB.FST146 AS FST146
      WHERE FST010.PGCOD = FST146.PGCOD AND FST010.EJCOD = FST146.EJCOD;
            */
      begin
         SELECT /*+ RULE*/ FST010.EJCOD
           into V_COD_OFICIAL
           FROM FST010, FST146
          WHERE FST010.PGCOD = FST146.PGCOD
            AND FST010.EJCOD = FST146.EJCOD
            and RTRIM(LTRIM(fst146.ubuser)) = trim(P_COD_OFICIAL)
            and rownum = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            -- si no se encuentran datos, se busca en supervisores
            begin
               SELECT /*+ RULE*/  U.COD_USU_SUPERVISOR
                 into v_usu_supervisor
                 FROM BA_USUARIOS     U,
                      GE_CLIENTES     C,
                      GE_CTA_CLIENTES CC,
                      GE_CUENTAS      GC,
                      GE_EST_CUENTAS  EC
                WHERE U.COD_USUARIO = C.COD_USU_OFICIAL
                  AND C.COD_PERSONA = CC.COD_PERSONA
                  AND CC.RELACION = 'P'
                     --
                  AND CC.NRO_CUENTA = GC.NRO_CUENTA
                     --
                  AND GC.COD_MODULO = EC.COD_MODULO
                  AND GC.COD_MODALIDAD = EC.COD_MODALIDAD
                  AND EC.ACTIVO = 'S'
                  and c.cod_usu_oficial = P_COD_OFICIAL
                  and rownum = 1;

               begin
                  SELECT /*+ RULE*/ FST010.EJCOD
                    into V_COD_OFICIAL
                    FROM FST010, FST146
                   WHERE FST010.PGCOD = FST146.PGCOD
                     AND FST010.EJCOD = FST146.EJCOD
                     and RTRIM(LTRIM(fst146.ubuser)) = v_usu_supervisor
                     and rownum = 1;
               exception
                  when no_data_found then
                     V_COD_OFICIAL := 777;
                  when others then
                     RAISE_APPLICATION_ERROR(-20000,
                                             '2- Error al obtener dato de oficial.' ||
                                             sqlerrm);
               end;
            EXCEPTION
            WHEN NO_dATA_FOUND THEN
               V_COD_OFICIAL := 777;
               --tool_pro_log_proceso(SYSDATE,'NO ENCONTRÓ OFICIAL', P_COD_OFICIAL);
            end;
      end;
      RETURN NVL(V_COD_OFICIAL, 777);
   exception
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al obtener dato de oficial.' ||
                                 sqlerrm);

   END;

   function FU_OBT_RIE_CLIENTE(P_COD_PAIS IN VARCHAR2, P_TIP_DOC IN VARCHAR2, P_NRO_DOC IN VARCHAR2) RETURN NUMBER IS
      V_PUNTAJE number(4);
   BEGIN
      begin
         select T.PSA044_HISpun/* || '-' || ltrim(rtrim(t.psa044dpu))*/ /* || '=' || ltrim(rtrim(T.psa044c01))*//*, 20)*/
           INTO V_PUNTAJE
           from PSA044_HIS t
          where t.PSA044_HISpai = P_COD_PAIS
            AND T.PSA044_HISTDO = P_TIP_DOC
            AND LTRIM(RTRIM(PSA044_HISNDO)) = P_NRO_DOC
            AND TO_DATE(t.PSA044_HISFFI, 'RRRRMMDD') = (select max(TO_DATE(b.PSA044_HISFFI, 'RRRRMMDD'))
                                                      from PSA044_HIS B
                                                     where B.PSA044_HISpai = P_COD_PAIS
                                                       AND B.PSA044_HISTDO = P_TIP_DOC
                                                       AND LTRIM(RTRIM(B.PSA044_HISNDO)) = P_NRO_DOC)
            AND ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_PUNTAJE := 0;
         WHEN OTHERS THEN
            V_PUNTAJE := 99;
      end;

      RETURN V_PUNTAJE;
   END;



   PROCEDURE PR_GEN_SCORING IS
      --v_nro_lote ge_pag_sue_emp.nro_lote%type;
   BEGIN

      PR_LOG_PSAML('PR_GEN_SCORING','INICIO PROCESO', to_char(sysdate));
      PR_LOG_PSAML('PR_GEN_SCORING','INSERTA TABLA', 'PSA047');
      PR_PRE_PRO_REGISTROS('PSA047',SYSDATE,'N');
      begin
           insert into psa047(
                        psa047pai,
                        psa047tdo,
                        psa047ndo,
                        psa047fec,
                        psa047nom,
                        psa047tpn,
                        psa047bca,
                        psa047prs,
                        psa047vac,
                        psa047vin,
                        psa047cop,
                        psa047cae,
                        psa047cpe,
                        psa047oce,
                        psa047suc,
                        psa047cof,
                        psa047rec,
                        psa047ori,
                        psa047est)

            Select distinct PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,p.cod_pais), 'BA_PAISES') cod_pais,
                PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') cod_tip_documento,
                T.NRO_CEDULA numero_documento,
                TO_CHAR(P.FEC_INSERCION, 'RRRRMMDD') fecha_alta,
                P.NOM_COMPLETO nombre_persona,
                P.TIPO tipo_persona,
                1 banca_cliente, --TODO: DE DÓNDE SACAR LA BANCA HOMOLOGADA
                PAI_PSA.FU_OBT_COD_BTL_PSA(DIR.COD_PAIS, 'BA_PAISES') cod_pai_residencia,
                NVL(pai_psa.FU_OBT_SAL_CLI(p.cod_persona, 'I'), 0) valor_activo,
                pai_psa.FU_OBT_SAL_CLI(p.cod_persona, 'I') valor_ingreso,
                PAI_PSA.FU_OBT_COD_BTL_PSA(NVL(PF.COD_PROFESION, 17),
                                           'BA_PROFESIONES') cod_ocupacion,
                --p.cod_rub_primario cod_act_economica, --TODX: OBTENER LA EQUIVALENCIA DE BANTOTAL
                PAI_PSA.FU_OBT_COD_BTL_PSA(NVL(P.COD_RUB_PRIMARIO,970108), 'GE_RUB_ECONOMICOS')cod_act_economica,
                PAI_PSA.FU_OBT_PEP(p.COD_PERSONA) PEP,
                'N' clie_ope_exterior,
                PAI_PSA.FU_OBT_COD_BTL_PSA(CTA.COD_OFICINA,
                                           'BA_OFICINAS') ciu_jur_sucursal,
                6 ori_fondo, --2 es payroll (clientes pago de nómina)
                11 rec_const_producto, --2 Payroll (Pagos de Salario): “Transferencia interna de tercero”
                'I' origen_datos, --I=ITGF / B=BANTOTAL WEB
                null estado --se envía vacío desde itgf


           from ge_pag_sue_emp    t,
                ba_personas       p,
                BA_PER_FISICAS    PF,
                ba_tip_documentos td,
                ba_paises         pa,
                ba_direcciones    dir,
                GE_CUENTAS        CTA,
                ge_lot_sco_masivo lot
          where  T.ESTADO = 'N' -- PROCESADO

            and lot.nro_lote_pro_nomina = t.nro_lote
            and trunc(lot.fec_ing_pro_nomina) = trunc(t.fec_insercion)
            and lot.estado = 'E'--PENIENTES
            and lot.fec_pro_socoring is null

            AND T.NRO_CUENTA = CTA.NRO_CUENTA
            AND P.COD_PERSONA = PF.COD_PERSONA
            and t.nro_cedula = p.nro_documento
            and t.tip_documento = td.abreviatura
            and td.cod_tip_documento = p.cod_tip_documento
            AND T.DOC_PAIS = PA.DESCRIPCION
            and dir.cod_persona = p.cod_persona
            and dir.principal = 'S'
            --control de duplicidad de clientes
            and not exists (select 1
                            from psa047_his a
                            where a.psa047_hispai = PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,p.cod_pais), 'BA_PAISES')
                            and   a.psa047_histdo = PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                            and   a.psa047_hisndo = T.NRO_CEDULA);
      exception
         when no_data_found then
            null;
         when others then
            raise_application_error(-20000, 'Error insertar datos de Scoring masivo: ' || sqlerrm);
      end;


      PR_LOG_PSAML('PR_GEN_SCORING','INSERTA TABLA', 'PSA048');
      --detalle
      PR_PRE_PRO_REGISTROS('PSA048',SYSDATE,'N');
      BEGIN
         insert into psa048(PSA048PAI,
                            PSA048TDO,
                            PSA048NDO,
                            PSA048MPR,
                            PSA048OPR,
                            PSA048IPR)
          Select distinct  PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,p.cod_pais), 'BA_PAISES') cod_pais,
                PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') cod_tip_documento,
                T.NRO_CEDULA numero_documento,
                DECODE(CTA.COD_MODULO, 3 , 21, 4, 20, 99) mod_producto,
                7 tip_producto,
                0 mto_producto
           from ge_pag_sue_emp    t,
                ba_personas       p,
                BA_PER_FISICAS    PF,
                ba_tip_documentos td,
                ba_paises         pa,
                ba_direcciones    dir,
                GE_CUENTAS        CTA,
                ge_lot_sco_masivo lot
          where  T.ESTADO = 'N' -- PROCESADO
            --and t.nro_lote = 178
            and lot.nro_lote_pro_nomina = t.nro_lote
            and trunc(lot.fec_ing_pro_nomina) = trunc(t.fec_insercion)
            and lot.estado = 'E'--PENIENTES
            and lot.fec_pro_socoring is null

            AND T.NRO_CUENTA = CTA.NRO_CUENTA
            AND P.COD_PERSONA = PF.COD_PERSONA
            and t.nro_cedula = p.nro_documento
            and t.tip_documento = td.abreviatura
            and td.cod_tip_documento = p.cod_tip_documento
            AND T.DOC_PAIS = PA.DESCRIPCION
            and dir.cod_persona = p.cod_persona
            and dir.principal = 'S'
            AND NOT EXISTS(SELECT 1
                           FROM PSA048_his W
                           WHERE W.PSA048_hisPAI = PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,p.cod_pais), 'BA_PAISES')
                           AND   W.PSA048_hisTDO = PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                           AND   W.PSA048_hisNDO = T.NRO_CEDULA
                           AND   W.PSA048_hisMPR = DECODE(CTA.COD_MODULO, 3 , 21, 4, 20, 99)
                           AND   W.PSA048_hisOPR = 7);

      EXCEPTION
      when no_data_found then
            null;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error insertar datos DETALLE de Scoring masivo: ' || sqlerrm);
      END;



      PR_LOG_PSAML('PR_GEN_SCORING','ACTUALIZA TABLA', 'GE_LOT_SCO_MASIVO');
      --se marca como procesado los lotes de alta masiva
      BEGIN
         UPDATE ge_lot_sco_masivo T SET T.FEC_PRO_SOCORING = SYSDATE,
                                        T.ESTADO = 'P' --PROCESADO
         WHERE T.FEC_PRO_SOCORING IS NULL
         AND   T.ESTADO = 'E';--PENDIENTE
      EXCEPTION
         WHEN OTHERS THEN
             raise_application_error(-20000, 'Error al actualizar lotes procesados de  Scoring masivo: ' || sqlerrm);
      END;
      commit;--se realiza el commit para que el notificador de mail obtenga los registros generados

      PR_ENV_MAIL(PAG_CAL.FU_OBT_FEC_ACTUAL(4),'SCORINGMASIVO');
      PR_LOG_PSAML('PR_GEN_SCORING','COMMIT', 'FIN');

   END;



   PROCEDURE PR_PRE_PRO_REGISTROS(P_NOM_TABLA IN VARCHAR2,
                                  P_FECHA     IN DATE,
                                  P_TIPO      IN VARCHAR2) IS
      V_TAB_HIST         VARCHAR2(500);
      SQL_TXT            VARCHAR2(4000);
      v_TRUNCAR_TABLA    VARCHAR2(2);
      V_LLEVAR_HISTORICO VARCHAR2(2);
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      --TABLAS TRUNCADAS Y LLEVADAS AL HISTÓRICO
      IF P_NOM_TABLA IN ('PSA003',--PSAML MOVIMIENTOS
                         'PSA047',--SCORING CLIENTES
                         'PSA048',--SCORING PRODUCTOS
                         'PSA023',--PIC MOVIMIENTOS
                         'PSA024',--PIC CLIENTES
                         'PSA025',--PIC PRODUCTOS
                         'PSA026',--PIC CANALES
                         'PSA027',--PIC SUCURSALES
                         'PSA057',--PIC CLIENTES CANALES CLI COMUN
                         'PSA058',--PIC PRODUCTOS CLI COMUN
                         'PSA059',--PIC JURIDICCION CLI COMUN
                         'PSA060' --PIC CLIENTE COMUN
                         ) THEN
         v_TRUNCAR_TABLA    := 'S';
         V_LLEVAR_HISTORICO := 'S';
      END IF;
      --TABLAS DE SOLO TRUNCAMIENTO
      IF P_NOM_TABLA IN ('PSA005') THEN
         v_TRUNCAR_TABLA    := 'S';
      END IF;

      IF V_LLEVAR_HISTORICO = 'S' THEN
         BEGIN
            --SE LLEVA AL HISTÓRICO
            V_TAB_HIST := P_NOM_TABLA || '_HIS';
            SQL_TXT    := 'INSERT INTO ' || V_TAB_HIST ||
                          '  SELECT * FROM ' || P_NOM_TABLA;
            EXECUTE IMMEDIATE SQL_TXT;

         END;
         commit;
      END IF;

      IF V_TRUNCAR_tABLA = 'S' THEN
         BEGIN
            --SE BORRA LOS REGISTROS DE LA TABLA
            SQL_TXT := 'TRUNCATE TABLE ' || P_NOM_TABLA;
            EXECUTE IMMEDIATE SQL_TXT;
         END;
         commit;
      END IF;

      BEGIN
         -- SE ACTUALIZA EL REGISTRO DEL PROCESO ANTERIOR
         UPDATE MI_PSA_PROCESOS T
            SET T.COD_ESTADO = 'T'
          WHERE T.NOM_TAB_PROCESO = P_NOM_TABLA
            AND T.FEC_PROCESO < P_FECHA
            AND T.COD_ESTADO != 'T';
      END;

      BEGIN
         --SE CREA EL REGISTRO DEL NUEVO PROCESO
         INSERT INTO MI_PSA_PROCESOS
            (NOM_TAB_PROCESO, FEC_PROCESO, COD_ESTADO)
         VALUES
            (P_NOM_TABLA, P_FECHA, P_TIPO);
      END;
      commit;
   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000, 'Error al enviar datos al histórico: ' || sqlerrm);
   END;

    PROCEDURE PR_ENV_MAIL(P_FEC_PROCESO IN DATE, P_TIP_PROCESO IN VARCHAR2) IS

       -- Variables para mail
       v_hin_mail    ge_ra_log_mail.hor_inicio%type;
       v_hfi_mail    ge_ra_log_mail.hor_fin%type;
       v_det_error   ge_ra_log_mail.det_error%type;
       v_para        varchar2(4000);
       v_asunto      varchar2(1000);
       v_mensaje     varchar2(4000);
       v_tip_proceso varchar2(500);
       PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
       BEGIN
          select decode(fug_obt_pardinamico('ENV_EMA_PRO_PSAML'),
                        null,
                        lower(FUG_OBT_DIR_MAIL_USU(user)),
                        lower(FUG_OBT_DIR_MAIL_USU(user)) || ';' || fug_obt_pardinamico('ENV_EMA_PRO_PSAML'))
            into v_para
            from dual;
       END;
       if V_REPROCESO = 'S' THEN
          v_tip_proceso := '(RE-PROCESO)';
       ELSE
          v_tip_proceso := '(NORMAL)';
       END IF;

       IF P_TIP_PROCESO = 'PSAML' THEN

          v_asunto := 'PSAML - proceso del: ' || P_FEC_PROCESO || ' FINALIZADO ' || v_tip_proceso;

          begin
             select 'Proceso PSAML de la fecha ' || P_FEC_PROCESO || ' finalizado ' || v_tip_proceso ||
                    ', a continuación se detalla la cantidad de registros generados por tabla' || chr(10) || 'TABLA - CANTIDAD REGISTROS' || chr(10) ||
                    'PSA001: ' || (Select count(*) from psa001) || chr(10) || 'PSA002: ' || (Select count(*) from psa002) || chr(10) || 'PSA003: ' ||
                    (Select count(*) from psa003) || chr(10) || 'PSA004: ' || (Select count(*) from psa004) || chr(10) || 'PSA005: ' ||
                    (Select count(*) from psa005) || chr(10) || 'PSA006: ' || (Select count(*) from psa006) || chr(10) || 'PSA007: ' ||
                    (Select count(*) from psa007) || chr(10)
               into v_mensaje
               FROM DUAL;
          end;

       ELSIF P_TIP_PROCESO = 'PIC' THEN
          v_asunto := 'PIC - proceso del: ' || P_FEC_PROCESO || ' FINALIZADO ' || v_tip_proceso;

          begin
             select 'Proceso PIC de la fecha ' || P_FEC_PROCESO || ' finalizado ' || v_tip_proceso ||
                    ', a continuación se detalla la cantidad de registros generados por tabla' || chr(10) || 'TABLA - CANTIDAD REGISTROS' || chr(10) ||
                    'PSA023: ' || (Select count(*) from psa023) || chr(10) ||
                    'PSA024: ' || (Select count(*) from psa024) || chr(10) ||
                    'PSA025: ' || (Select count(*) from psa025) || chr(10) ||
                    'PSA026: ' || (Select count(*) from psa026) || chr(10) ||
                    'PSA027: ' || (Select count(*) from psa027) || chr(10) ||
                    'PSA057: ' || (Select count(*) from psa057) || chr(10) ||
                    'PSA058: ' || (Select count(*) from psa058) || chr(10) ||
                    'PSA059: ' || (Select count(*) from psa059) || chr(10) ||
                    'PSA060: ' || (Select count(*) from psa060) || chr(10)
               into v_mensaje
               FROM DUAL;
          end;

       ELSIF P_TIP_PROCESO = 'SCORINGMASIVO' THEN
          begin
             select 'Proceso SCORING MASIVO de la fecha ' || P_FEC_PROCESO || ' finalizado ' ||
                    ', a continuación se detalla la cantidad de registros generados por tabla' || chr(10) || 'TABLA - CANTIDAD REGISTROS' || chr(10) ||
                    'PSA047: ' || (Select count(*) from psa047) || chr(10) ||
                    'PSA048: ' || (Select count(*) from psa048) || chr(10)
               into v_mensaje
               FROM DUAL;
          end;

       END IF;

       BEGIN
          v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
          it_mail.mail(fug_obt_dir_correo, v_para, v_asunto, v_mensaje);
          v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
       EXCEPTION
          when others then
             v_det_error := substr(sqlerrm, 1, 4000);
             INSERT INTO ge_ra_log_mail
                (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
             VALUES
                (SYSDATE,
                 null,
                 substr(v_para, 1, 4000),
                 substr(v_asunto || chr(10) || v_mensaje, 1, 2000),
                 substr(v_det_error, 1, 4000),
                 v_hin_mail,
                 v_hfi_mail);
             commit;
       END;
    END;

   --Procedimiento para preparar los registros de las tablas de bantotal (ej.: eliminar los espacios en blanco)
   PROCEDURE PR_ACT_TAB_BANTOTAL IS
   BEGIN
      --TABLA PERSONA
      UPDATE FSD001 T SET T.PENDOC = LTRIM(RTRIM(T.PENDOC));
      commit;
      --TABLA RESULTADOS PIC
      UPDATE PSA044_HIS T SET T.PSA044_HISNDO = LTRIM(RTRIM(T.PSA044_HISNDO));
      commit;
   END;

   PROCEDURE PR_TRU_TAB_BANTOTAL IS
      SQL_TXT            VARCHAR2(4000);
   BEGIN
      BEGIN
         --SE BORRA LOS REGISTROS DE LA FSD001
         SQL_TXT := 'TRUNCATE TABLE FSD001';
         EXECUTE IMMEDIATE SQL_TXT;
      END;

      BEGIN
         --SE BORRA LOS REGISTROS DE LA FST010
         SQL_TXT := 'TRUNCATE TABLE FST010';
         EXECUTE IMMEDIATE SQL_TXT;
      END;

      BEGIN
         --SE BORRA LOS REGISTROS DE LA FST146
         SQL_TXT := 'TRUNCATE TABLE FST146';
         EXECUTE IMMEDIATE SQL_TXT;
      END;

   END;

  PROCEDURE PR_ACT_CLI_COMUNES IS
     cursor c_clientes is
        select a.cod_persona
          from (SELECT DISTINCT A1.COD_PERSONA FROM ge_cta_imp_psaml A1 WHERE A1.EXI_ENBANTOTAL = 'N') a, BA_PERSONAS p
         where a.cod_persona = p.cod_persona
           AND PAI_PSA.FU_CLI_EXI_ENBANTOTAL(pai_psa.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento, p.cod_pais), 'BA_PAISES'),
                                             PAI_PSA.FU_OBT_COD_BTL_PSA(P.COD_TIP_DOCUMENTO, 'BA_TIP_DOCUMENTOS'),
                                             P.NRO_DOCUMENTO) = 'S';

  BEGIN
     FOR C IN C_CLIENTES LOOP
        UPDATE GE_CTA_IMP_PSAML T SET T.Exi_Enbantotal = 'S'
        WHERE T.COD_PERSONA = C.COD_PERSONA;
     END LOOP;

  END;

   PROCEDURE PR_ACT_CTA_CLIENTES IS
      v_tot_reg_act_reg number(10) := 0;
      v_tot_reg_act_ok  number(10) := 0;
   begin

      --verificación de cuentas duplicadas
      begin
         select count(*) into v_tot_reg_act_reg from (Select psa006ct from psa006 where psa006so = 1 group by psa006ct having count(*) > 1) a;
      end;

      if v_tot_reg_act_reg > 0 THEN
         -- 1 marcamos las cuentas que deben ser regeneradas para actualizar sus datos
         begin
            update MI_CTA_CLIENTES t
               set t.referencia1 = 'REGENERAR'
             WHERE T.NRO_CTA_BANTOTAL IN (Select psa006ct from psa006 where psa006so = 1 group by psa006ct having count(*) > 1)
               AND T.NRO_SUB_CTA_BANTOTAL = 1;
         end;

         -- 2 se borra las cuentas que están duplicadas
         begin
            delete from psa006 t
             where t.psa006ct in (Select psa006ct from psa006 where psa006so = 1 group by psa006ct having count(*) > 1)
               and t.psa006so = 1;
         end;
         -- 3 se inserta las cuentas con los datos actualizados
         begin
            insert into psa006
               (PSA006PA,
                PSA006TD,
                PSA006DO,
                PSA006MO,
                PSA006CT,
                PSA006SO,
                PSA006ST,
                PSA006FC,
                PSA006CP,
                PSA006LT,
                PSA006FO,
                PSA006EJ,
                PSA006BC,
                PSA006NC,
                PSA006CO,
                PSA006TF,
                PSA006BR) --BANCO REMITENTE
               SELECT *
                 FROM (SELECT PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per.cod_pai_documento, per.cod_pais), 'BA_PAISES') PSA006PA --Pais
                             ,
                              PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_tip_documento, 'BA_TIP_DOCUMENTOS') PSA006TD --Tipo de documento
                             ,
                              per.nro_documento PSA006DO --Documento
                             ,
                              PAI_PSA.FU_OBT_COD_BTL_PSA(CTA.cod_modulo, CTA.cod_modalidad, 'MODULOS_PRODUCTOS') PSA006MO --Cod Producto BT
                             ,
                              MCT.NRO_CTA_BANTOTAL PSA006CT,
                              MCT.NRO_SUB_CTA_BANTOTAL PSA006SO --Sub Operacion
                             ,
                              DECODE(EC.ACTIVO, 'S', 0, 99) PSA006ST --Estado (NORMAL O ACTIVA)
                             ,
                              TO_CHAR(CTA.FEC_APERTURA, 'rrrrMMDD') PSA006FC --Fecha de creacion
                             ,
                              0 PSA006CP --Codigo producto
                             ,
                              (case
                                 when ctacli.cod_modulo = 5 then
                                  nvl((select l.lin_credito from ta_cta_tarjetas l where l.nro_cuenta = ctacli.nro_cuenta), 0)
                                 else
                                  0
                              end) PSA006LT --Limite de TC
                             ,
                              TO_TIMESTAMP(TO_CHAR(CLI.fec_ingreso, 'rrrr-MM-DD HH24:MI:SS'), 'YYYY-MM-DD HH24:MI:SS') PSA006FO --Fecha y hora de ingraso
                             ,
                              PSA.COD_OFI_BANTOTAL PSA006EJ,
                              PAI_PSA.FU_OBT_COD_BTL_PSA(cli.cod_seg_cliente, 'GE_SEG_CLIENTES') PSA006BC --Banca
                             ,
                              trim(lpad(REPLACE(CTA.DENOMINACION, CHR(10), ' '), 70)) PSA006NC --Nombre cuenta
                             ,
                              decode(ctacli.relacion, 'P', 1, 2) PSA006CO --Codigo Titular
                             ,
                              decode(ctacli.relacion, 'P', 'T', '') PSA006TF --Titular Firmante
                             ,
                              'B' --BANCO REMITENTE
                         FROM GE_CTA_CLIENTES  CTACLI,
                              GE_CUENTAS       CTA,
                              GE_CLIENTES      CLI,
                              ba_personas      per,
                              GE_CTA_IMP_PSAML PSA,
                              GE_EST_CUENTAS   EC,
                              MI_CTA_CLIENTES  MCT
                        WHERE CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
                          AND CTACLI.COD_PERSONA = CLI.COD_PERSONA
                             ----NRO DE CUENTAS DUPLICADAS POR ACTUALIZACIÓN EN COD PAIS DOCUMENTO O NRO DE DOCUMENTO
                          AND MCT.NRO_CTA_ITGF = CTACLI.NRO_CUENTA
                          AND MCT.COD_PERSONA = CTACLI.COD_PERSONA

                          and mct.nro_sub_cta_bantotal = 1
                          and mct.referencia1 = 'REGENERAR' --cuentas que se deben regenerar
                          and cli.cod_persona = per.cod_persona
                          AND CTACLI.NRO_CUENTA = PSA.NRO_CUENTA
                          AND CTACLI.COD_PERSONA = PSA.COD_PERSONA
                          AND CTA.COD_MODULO = EC.COD_MODULO
                          AND CTA.COD_MODALIDAD = EC.COD_MODALIDAD
                          AND CTA.ESTADO = EC.ESTADO) CTAS_PSAML
                WHERE NOT EXISTS (SELECT 'S'
                         FROM PSA006 A6
                        WHERE A6.PSA006PA = CTAS_PSAML.PSA006PA -- PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_pais, 'BA_PAISES')
                          AND A6.PSA006TD = CTAS_PSAML.PSA006TD --PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                          AND A6.PSA006DO = CTAS_PSAML.PSA006DO --per.nro_documento
                          AND A6.PSA006MO = CTAS_PSAML.PSA006MO --PAI_PSA.FU_OBT_COD_BTL_PSA(CTA.cod_modulo, CTA.cod_modalidad, 'MODULOS_PRODUCTOS')
                          AND A6.PSA006CT = CTAS_PSAML.PSA006CT --7||lpad(per.cod_persona,8,0)
                          AND A6.PSA006SO = CTAS_PSAML.PSA006SO); --pai_psa.FU_OBT_NRO_SUB_OPERACION(per.cod_persona, ctacli.nro_cuenta));
         exception
            when others then
               raise_application_error(-20000, 'Error insertar datos de productos REGENERADOS: ' || sqlerrm);
         end;

         -- 4 marcamos las cuentas  regeneradas
         begin
            update MI_CTA_CLIENTES t
               set t.referencia1 = null,
                   t.referencia2 = 'CTA ACTUALIZADA POR ACT EN LA PERSONA.'
             WHERE T.referencia1 = 'REGENERAR'
               AND T.NRO_SUB_CTA_BANTOTAL = 1;
            v_tot_reg_act_ok := sql%rowcount;
         end;
         -- 5 control de ajustes realizados
         if v_tot_reg_act_ok = v_tot_reg_act_reg then
            --TODO CORRECTO

            -- 6 se vuelve a controlar si quedaron duplicados los datos de cuentas
            begin
               update MI_CTA_CLIENTES t
                  set t.referencia1 = 'REGENERAR'
                WHERE T.NRO_CTA_BANTOTAL IN (Select psa006ct from psa006 where psa006so = 1 group by psa006ct having count(*) > 1)
                  AND T.NRO_SUB_CTA_BANTOTAL = 1;
               v_tot_reg_act_reg := sql%rowcount;
            end;
            if v_tot_reg_act_reg > 0 then
               raise_application_error(-20000, 'Existen ' || v_tot_reg_act_reg || ' Cuentas duplicadas PSAML, se debe verificar.');
            else
               commit;

            end if;
         else
            raise_application_error(-20000,
                                    'Actualización incorrecta de cuentas PSAML: v_tot_reg_act_ok:' || v_tot_reg_act_ok || ' v_tot_reg_act_reg:' ||
                                     v_tot_reg_act_reg);
         end if;
      end if;
   END;




   PROCEDURE PR_PAS_HIS_PIC_RESULT IS
      SQL_TXT     VARCHAR2(4000);
      V_NOM_TABLA VARCHAR2(200) := 'PSA044';
      V_TAB_HIST  VARCHAR2(200);
      V_HAY_DATOS VARCHAR2(2);
   BEGIN
      V_TAB_HIST := V_NOM_TABLA || '_HIS';
      BEGIN
         --REVISA SI EXISTE DATOS EN PSA044
         BEGIN
            SELECT 'S' INTO V_HAY_DATOS FROM PSA044 t where rownum = 1;
         exception
            when no_data_found then
               v_hay_datos := 'N';
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000, 'Error al controlar registros de resultados pic PSA044: ' || sqlerrm);
         END;

         IF V_HAY_DATOS = 'S' THEN
            BEGIN
               --SE BORRA LOS REGISTROS DE LA TABLA histórica
               SQL_TXT := 'TRUNCATE TABLE ' || V_TAB_HIST;
               EXECUTE IMMEDIATE SQL_TXT;
            END;
            COMMIT;

            --SE LLEVA AL HISTÓRICO
            BEGIN
               SQL_TXT := 'INSERT INTO ' || V_TAB_HIST || '  SELECT * FROM ' || V_NOM_TABLA;
               EXECUTE IMMEDIATE SQL_TXT;
            END;
            COMMIT;

            BEGIN
               --SE BORRA LOS REGISTROS DE LA TABLA
               SQL_TXT := 'TRUNCATE TABLE ' || V_NOM_TABLA;
               EXECUTE IMMEDIATE SQL_TXT;
            END;
            COMMIT;

         END IF;

      END;
      COMMIT;

   END;



   --procedimiento de generación de cuentas bantotal
   PROCEDURE PR_MIG_CTA_CLIENTES IS
      --V_EXI_REGISTROS VARCHAR2(2) := 'N';
      v_ult_nro_cta_bantotal number(9):=0;
      CURSOR C_CTAS_FIRMANTES IS
         SELECT DISTINCT PS.NRO_CUENTA
           FROM ge_cta_imp_psaml PS, GE_CTA_CLIENTES CL
          WHERE PS.NRO_CUENTA = CL.NRO_CUENTA
            AND CL.RELACION != 'P'
            and ps.nro_cuenta not in (select a.nro_cta_itgf
                                      from mi_cta_clientes a
                                      where a.principal ='N');
         --actualización masiva de las cuentas, se asigna el módulo bantotal                             
         procedure pr_act_cta_modulos is
            cursor c_cuentas is
               select distinct mc.nro_cta_itgf,
                               c.cod_modulo,
                               c.cod_modalidad
                 from mi_cta_clientes mc,
                      ge_cuentas      c
                where mc.nro_cta_itgf = c.nro_cuenta
                  and mc.referencia3 is null; --todas las cuentas que no tenga el valor de módulo vantotal

         begin
            for c in c_cuentas loop
               update mi_cta_clientes t
                  set t.referencia3 = PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_modulo, c.cod_modalidad, 'MODULOS_PRODUCTOS')
                where t.nro_cta_itgf = c.nro_cta_itgf;
            end loop;

         end;

   BEGIN


       begin
          select to_number(substr(max(a.nro_ctA_bantotal), -8))
            into v_ult_nro_cta_bantotal
            from mi_cta_clientes a;
       exception
          when no_data_found then
             v_ult_nro_cta_bantotal := 0;
          when others then

             RAISE_APPLICATION_ERROR(-20000,
                                     'Error al controlar registros de cuentas y sub operación: ' ||
                                     sqlerrm);
       end;




         PR_LOG_PSAML('INICIO CURSOR PRINCIPALES');

         INSERT INTO mi_cta_clientes
            (COD_PERSONA, NRO_CTA_ITGF, NRO_CTA_BANTOTAL, PRINCIPAL, NRO_SUB_CTA_BANTOTAL)
            select T.COD_PERSONA,
                   T.NRO_CUENTA,
                   7 || lpad(nvl(v_ult_nro_cta_bantotal,0) + ROWNUM, 8, 0) NRO_CTA_BANTOTAL,
                   'P' PRINCIPAL,
                   1 NRO_SUB_OPERACION
              from ge_Cta_clientes t
             where t.relacion = 'P'
               and exists
             (select 1 from ge_cta_imp_psaml a where a.nro_cuenta = t.nro_cuenta)
             and T.nro_cuenta not in (select a.nro_cta_itgf from mi_cta_clientes a)
             ORDER BY T.COD_PERSONA;

         --END LOOP;
         PR_LOG_PSAML('INICIO CURSOR FIRMANTES');
         FOR FIR IN C_CTAS_FIRMANTES LOOP
            --logtest('FIRMANTES',FIR.NRO_CUENTA);
            INSERT INTO mi_cta_clientes
               (COD_PERSONA, NRO_CTA_ITGF, NRO_CTA_BANTOTAL, PRINCIPAL, NRO_SUB_CTA_BANTOTAL)
               select T.COD_PERSONA,
                      T.NRO_CUENTA,
                      MC.NRO_CTA_BANTOTAL NRO_CTA_BANTOTAL,
                      'N' PRINCIPAL,
                      ROWNUM + 1 NRO_SUB_OPERACION
                 from ge_Cta_clientes t, MI_CTA_CLIENTES MC, ge_cta_imp_psaml ctp
                where t.relacion != 'P'
                  AND T.NRO_CUENTA = MC.NRO_CTA_ITGF
                  and t.nro_cuenta = ctp.nro_cuenta
                  and t.cod_persona = ctp.cod_persona
                  AND MC.PRINCIPAL = 'P'
                  AND T.NRO_CUENTA = FIR.NRO_CUENTA
                ORDER BY T.NRO_CUENTA;

         END LOOP;
      --END IF;
      COMMIT;
      
      --actualización masiva de las cuentas con su módulo equivalente de bantotal
      pr_act_cta_modulos;
      commit;
   END;

   PROCEDURE PR_MIG_CTA_CLIENTES_DEV(P_FEC_DESDE IN DATE, P_FEC_HASTA IN DATE) IS
      CURSOR C_CLIENTES IS
         select DISTINCT T.COD_PERSONA
           from ge_Cta_clientes t, GE_CUENTAS C, GE_EST_CUENTAS E
          where /*t.relacion = 'P'
                        AND */
          T.NRO_CUENTA = C.NRO_CUENTA
          AND T.COD_MODULO = C.COD_MODULO
          AND T.COD_MODALIDAD = C.COD_MODALIDAD
          AND C.COD_MODULO = E.COD_MODULO
          AND C.COD_MODALIDAD = E.COD_MODALIDAD
          AND C.ESTADO = E.ESTADO
         --AND E.ACTIVO = 'S'
          and (e.activo = 'S' or (e.activo = 'N' and TRUNC(c.FEC_MODIFICACION) >= TRUNC(P_FEC_DESDE) and
          TRUNC(c.FEC_MODIFICACION) <= TRUNC(P_FEC_HASTA)));

      V_EXI_REGISTROS VARCHAR2(2) := 'N';
   BEGIN
      BEGIN
         SELECT 'S' INTO V_EXI_REGISTROS FROM mi_cta_clientes A where rownum = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_EXI_REGISTROS := 'N';
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,
                                    'Error al controlar registros de cuentas y sub operación: ' ||
                                    sqlerrm);
      END;

      IF V_EXI_REGISTROS = 'N' THEN
         FOR C IN C_CLIENTES LOOP
            INSERT INTO mi_cta_clientes
               (cod_persona, nro_cta_itgf, nro_cta_bantotal, nro_sub_cta_bantotal)
               select T.COD_PERSONA, T.NRO_CUENTA, 0 NRO_CTA_BANTOTAL, ROWNUM NRO_SUB_OPERACION
                 from ge_Cta_clientes t, GE_CUENTAS C, GE_EST_CUENTAS E
                where /*t.relacion = 'P'
                                    AND */
                T.NRO_CUENTA = C.NRO_CUENTA
                AND T.COD_MODULO = C.COD_MODULO
                AND T.COD_MODALIDAD = C.COD_MODALIDAD
                AND C.COD_MODULO = E.COD_MODULO
                AND C.COD_MODALIDAD = E.COD_MODALIDAD
                AND C.ESTADO = E.ESTADO
               --AND E.ACTIVO = 'S'
                AND T.COD_PERSONA = C.COD_PERSONA
                and (e.activo = 'S' or
                (e.activo = 'N' and TRUNC(c.FEC_MODIFICACION) >= TRUNC(P_FEC_DESDE) AND
                TRUNC(c.FEC_MODIFICACION) <= TRUNC(P_FEC_HASTA)))
                ORDER BY T.NRO_CUENTA;

         END LOOP;
      END IF;
      COMMIT;
   END;

   -- Inserta datos de Clientes y Cuentas de ASSIST en un temporal.
   PROCEDURE PR_INS_CTA_PSAML(P_FEC_PROCESO IN DATE) IS

   BEGIN
      -- Inicializar parámetros ITGF.
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      -- Elimino registros de la fecha para volver a cargarlo
      if V_REPROCESO = 'S' THEN
         BEGIN
            DELETE GE_CTA_IMP_PSAML WHERE TRUNC(FEC_PROCESO) = P_FEC_PROCESO;--TRUNC(PAI_PSA.FU_OBT_FEC_PROCESO);
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               NULL;
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000, 'Error al eliminar registros de la fecha ' || sqlerrm);
         END;
      --COMMIT;
      END IF;

      --*Se omite el llamado a este proceso debido a que ya fue llamado antes: PR_ACT_TAB_BANTOTAL;

      INSERT INTO GE_CTA_IMP_PSAML
            (NRO_CUENTA,
             COD_PERSONA,
             FEC_PROCESO,
             EXI_ENBANTOTAL,
             NRO_CTA_BANTOTAL)
      select ctas_psaml.nro_cuenta,
          ctas_psaml.cod_persona,
          ctas_psaml.fec_proceso,
          ctas_psaml.cli_bantotal,
          0 cta_bantotal
           from (SELECT CTACLI.NRO_CUENTA,
                        CTACLI.COD_PERSONA,
                        --PAI_PSA.FU_OBT_FEC_PROCESO FEC_PROCESO,
                        P_FEC_PROCESO fec_proceso,
                        PAI_PSA.FU_CLI_EXI_ENBANTOTAL(PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per.cod_pai_documento,pER.Cod_pais),'BA_PAISES'),
                                                      PAI_PSA.FU_OBT_COD_BTL_PSA(pER.cod_tip_documento,'BA_TIP_DOCUMENTOS'),
                                                      PER.NRO_DOCUMENTO) CLI_BANTOTAL
                   FROM GE_CTA_CLIENTES CTACLI,
                        GE_CLIENTES     CLI,
                        GE_CUENTAS      CTA,
                        BA_PERSONAS     PER,
                        GE_EST_CUENTAS  EST
                  WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
                    AND CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
                    AND CTACLI.COD_PERSONA = PER.COD_PERSONA
                    AND TRUNC(CLI.FEC_INSERCION) <= TRUNC(P_FEC_PROCESO)
                    and est.cod_modulo = cta.cod_modulo
                    and est.cod_modalidad = cta.cod_modalidad
                    AND EST.ESTADO = CTA.ESTADO
                    --EXCLUIR LAS CUENTAS DE BANCARD
                    AND CTA.NRO_CUENTA NOT IN (select distinct c.nro_cuenta
                                               from Ge_Cta_Clientes t
                                                   ,ge_cuentas       c
                                              where t.nro_cuenta = c.nro_cuenta
                                                and c.cod_modalidad in (31, 41)/*ahorro y cta cte*/
                                                and c.cod_sub_modalidad = 25/*sub modalidad transaccional*/
                                                and t.cod_persona = 149064/*cod persona bancard*/)
                    --and est.activo = 'S'
                    and (est.activo = 'S' or
                        (est.activo = 'N' and TRUNC(CTA.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO)))
                    and exists (select 's'
                           from ge_cum_transacciones tr
                          where tr.cod_modulo = ctacli.cod_modulo
                            and tr.cod_modalidad = ctacli.cod_modalidad
                            and tr.ind_monitoreo = 'S'
                            /*and rownum = 1*/)
                    AND NOT EXISTS (SELECT 1
                           FROM GE_CTA_IMP_PSAML
                          WHERE NRO_CUENTA = CTACLI.NRO_CUENTA
                            AND COD_PERSONA = CTACLI.COD_PERSONA
                            /*and rownum = 1*/)) ctas_psaml;


      --
      COMMIT;
      --
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al cargar temporal de cuentas para PSAML: ' || sqlerrm);
   END;

      -- Inserta datos de Clientes y Cuentas de ASSIST en un temporal.
   PROCEDURE PR_INS_CTA_PSAML_DEV(P_FEC_dESDE IN DATE, P_FEC_HASTA IN DATE) IS
      V_CONTADOR NUMBER;

      CURSOR C_CURSOR IS
         select ctas_psaml.nro_cuenta,
          ctas_psaml.cod_persona,
          ctas_psaml.fec_proceso,
          ctas_psaml.cli_bantotal,
          /*decode(cli_bantotal,
                 'S',
                 FUN_OBTENER_CUENTA_BT_2(ctas_psaml.NRO_CUENTA),
                 0)*/0 cta_bantotal
           from (SELECT CTACLI.NRO_CUENTA,
                        CTACLI.COD_PERSONA,
                        PAI_PSA.FU_OBT_FEC_PROCESO FEC_PROCESO,
                        PAI_PSA.FU_CLI_EXI_ENBANTOTAL(PAI_PSA.FU_OBT_COD_BTL_PSA(pER.Cod_pais,'BA_PAISES'),
                                                      PAI_PSA.FU_OBT_COD_BTL_PSA(pER.cod_tip_documento,'BA_TIP_DOCUMENTOS'),
                                                      PER.NRO_DOCUMENTO) CLI_BANTOTAL
                   FROM GE_CTA_CLIENTES CTACLI,
                        GE_CLIENTES     CLI,
                        GE_CUENTAS      CTA,
                        BA_PERSONAS     PER,
                        GE_EST_CUENTAS  EST
                  WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
                    AND CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
                    AND CTACLI.COD_PERSONA = PER.COD_PERSONA
                    AND TRUNC(CLI.FEC_INSERCION) <= TRUNC(P_FEC_HASTA)
                    and est.cod_modulo = cta.cod_modulo
                    and est.cod_modalidad = cta.cod_modalidad
                    AND EST.ESTADO = CTA.ESTADO
                    --and est.activo = 'S'
                    and (est.activo = 'S' or
                        (est.activo = 'N' and TRUNC(CTA.FEC_MODIFICACION) >= TRUNC(P_FEC_DESDE)/*
                                          and TRUNC(CTA.FEC_MODIFICACION) <= TRUNC(P_FEC_HASTA)*/))
                    and exists (select 's'
                           from ge_cum_transacciones tr
                          where tr.cod_modulo = ctacli.cod_modulo
                            and tr.cod_modalidad = ctacli.cod_modalidad
                            and tr.ind_monitoreo = 'S'
                            and rownum = 1)
                    AND NOT EXISTS (SELECT 1
                           FROM GE_CTA_IMP_PSAML
                          WHERE NRO_CUENTA = CTACLI.NRO_CUENTA
                            AND COD_PERSONA = CTACLI.COD_PERSONA
                            and rownum = 1)) ctas_psaml;
   BEGIN
      -- Inicializar parámetros ITGF.
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      -- Elimino registros de la fecha para volver a cargarlo
      BEGIN
         DELETE GE_CTA_IMP_PSAML WHERE TRUNC(FEC_PROCESO) = TRUNC(PAI_PSA.FU_OBT_FEC_PROCESO);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Error al eliminar registros de la fecha ' || sqlerrm);
      END;
      -- Confirmo la eliminación.
      COMMIT;
      -- Inserta las cuentas que GE_CTA_IMP_PSAML que se informarán a ASSIST
      V_CONTADOR := 0;
      --
      FOR F_CURSOR IN C_CURSOR LOOP
         V_CONTADOR := V_CONTADOR + 1;
         INSERT INTO GE_CTA_IMP_PSAML
            (NRO_CUENTA,
             COD_PERSONA,
             FEC_PROCESO,
             EXI_ENBANTOTAL,
             NRO_CTA_BANTOTAL)
         VALUES
            (F_CURSOR.NRO_CUENTA,
             F_CURSOR.COD_PERSONA,
             F_CURSOR.FEC_PROCESO,
             F_CURSOR.cli_bantotal,
             F_CURSOR.cta_bantotal);
         IF V_CONTADOR = 10000 THEN
            COMMIT;
            V_CONTADOR := 0;
         END IF;
      END LOOP;
      --
      COMMIT;
      --
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al cargar temporal de cuentas para PSAML: ' || sqlerrm);
   END;

   -- Archivo de Clientes
   PROCEDURE PR_GEN_ARC_CLIENTES(P_FEC_PROCESO IN DATE) IS
   BEGIN

      BEGIN
         IF V_REPROCESO = 'S' THEN
             delete psa007 t
             where exists (select 's'
                      from (SELECT C.COD_PERSONA, c.fec_proceso
                              FROM GE_CTA_IMP_PSAML C
                              WHERE C.EXI_ENBANTOTAL = 'N') ct,
                           BA_PERSONAS P
                     WHERE Ct.COD_PERSONA = P.COD_PERSONA
                       AND Ct.FEC_PROCESO = P_FEC_PROCESO
                       AND p.nro_documento = t.Psa007do
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,
                                                          p.cod_pais),
                                                      'BA_PAISES') =
                           t.Psa007pa
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento,
                                                      'BA_TIP_DOCUMENTOS') =
                           t.Psa007DT);
         END IF;
      END;


      begin dbms_stats.gather_table_stats('IT','PSA044_HIS'); end;
      begin
            PR_PRE_PRO_REGISTROS('PSA007',SYSDATE,V_REPROCESO);
            PR_LOG_PSAML('PR_ACT_PAS_ACT_CLIENTE','INICIO');
            PR_ACT_PAS_ACT_CLIENTE;
            PR_LOG_PSAML('PR_ACT_PAS_ACT_CLIENTE','FIN');
            insert into psa007
               (psa007a1,
                psa007a2,
                psa007ac,
                psa007ae,
                psa007ap,
                psa007ca,
                psa007ce,
                psa007cp,
                psa007cr,
                psa007ct,
                psa007dc,
                psa007de,
                psa007di,
                psa007dl,
                psa007dn,
                psa007do,
                psa007dp,
                psa007dt,
                psa007eg,
                psa007em,
                psa007es,
                psa007fa,
                psa007fp,
                psa007fr,
                psa007ge,
                psa007im,
                psa007in,
                psa007ip,
                psa007n2,
                psa007na,
                psa007nc,
                psa007oc,
                psa007of,
                psa007os,
                psa007pa,
                psa007pe,
                psa007pf,
                psa007pn,
                psa007pr,
                psa007pt,
                psa007pv,
                psa007re,
                psa007ri,
                psa007rs,
                psa007sl,
                psa007ta,
                psa007te,
                psa007tp,
                psa007vd,
                PSA007BR)--BANCO REMITENTE
                  Select
                  -- TRIM(lpad(PAI_PSA.FU_OBT_APE_CLIENTE(p.COD_PERSONA, p.TIPO, 1), 30)) psa007a1 --'Primer apellido';

                   lpad(DECODE(P.TIPO,
                          'F',
                          nvl(pf.pri_apellido, 'SIN APELLIDO'),
                          'J',
                          NVL(PJ.NOM_COMERCIAL, 'SIN DENOMINACION'),
                          '---'),30) psa007a1 --'Primer apellido';

                   --,TRIM(lpad(PAI_PSA.FU_OBT_APE_CLIENTE(p.COD_PERSONA, p.TIPO, 2), 30)) psa007a2 --'Segundo apellido';

                  ,
                   lpad(DECODE(P.TIPO,
                          'F',
                          nvl(pf.Seg_Apellido, 'SIN APELLIDO'),
                          'J',
                          NVL(PJ.NOM_COMERCIAL, 'SIN DENOMINACION'),
                          '---'),30) psa007a2 --'Segundo apellido';

                   --,PAI_PSA.FU_OBT_SAL_CLI(p.COD_PERSONA, 'A') psa007ac --'Total de activo'; TODO
                  ,
                   NVL(SAL.TOT_ACTIVO, 0) psa007ac --'Total de activo'; TODO

                  ,
                   nvl(p.cod_rub_primario,'749911') psa007ae --'Actividad economica';
                  ,
                   TO_TIMESTAMP(to_char(p.fec_modificacion, 'rrrr-MM-DD HH24:MI:SS'),
                                'YYYY-MM-DD HH24:MI:SS') psa007ap --'Fecha actualiacion en el sistema';
                  ,
                   null psa007ca --'Correo electronico adicional';
                  ,
                   TRIM(lpad(p.DIR_CORREO, 60)) psa007ce --'Correo electronico principal';
                   --,TRIM(PAI_PSA.FU_OBT_PEP(p.COD_PERSONA)) psa007cp -- 'Cargo PEP';
                  ,
                   DECODE(NVL(pep.PEP, 'N'), 'N', 'N', 'Y') psa007cp -- 'Cargo PEP';

                   /*,TRIM(lpad(PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(PAI_PSA.FU_OBT_COD_CIU(p.COD_PERSONA, 'C'),
                   p.COD_PAIS), 20)) psa007cr --'Ciudad de residencia';*/

                  ,
                   TRIM(lpad(CR.DESCRIPCION, 20)) psa007cr --'Ciudad de residencia';

                   /*,TRIM(lpad(PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(PAI_PSA.FU_OBT_COD_CIU(p.COD_PERSONA, 'CL'),
                   p.COD_PAIS), 20)) psa007ct --'Ciudad laboral';*/

                  ,
                   TRIM(lpad(Cr.DESCRIPCION, 20)) psa007ct --'Ciudad laboral';

                  ,
                   null psa007dc --'Direccion ocacional';
                   /*,TRIM(PAI_PSA.FU_OBT_COD_BTL_PSA(PAI_PSA.FU_OBT_COD_CIU(p.COD_PERSONA, 'D'),
                   'BA_DEPARTAMENTOS')) psa007de --'Departamento';*/

                  ,
                   TRIM(PAMD.VAL_COD_BANTOTAL) psa007de --'Departamento';

                   --,TRIM(pai_psa.FU_OBT_DIR_PRINCIPAL(p.cod_persona, 'P')) psa007di --8'Direccion particular';

                  ,
                   TRIM(dr.DIRECCION) psa007di --8'Direccion particular';

                   --,TRIM(pai_psa.FU_OBT_DIR_PRINCIPAL(p.cod_persona, 'L')) psa007dl --'Direccion laboral';

                  ,
                   TRIM(dr.direccion) psa007dl --'Direccion laboral';

                   --,TRIM(pAI_PSA.FU_OBT_NOM_CLIENTE(p.COD_PERSONA, p.TIPO, 1)) psa007dn --'Denominacion/Primer Nombre';

                  ,
                   DECODE(P.TIPO, 'F', nvl(pf.pri_nombre, 'SIN NOMBRE'), 'J', '   ', '---') psa007dn --'Denominacion/Primer Nombre';

                  ,
                   p.nro_documento psa007do --'Documento';
                   --,TRIM(pai_psa.FU_OBT_DIR_PRINCIPAL(p.cod_persona, 'PP')) psa007dp --'Direccion principal';

                  ,
                   TRIM(dr.direccion) psa007dp --'Direccion principal';

                   --,TRIM(PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS')) psa007dt --'Tipo doc';

                  ,
                   PAMTD.VAL_COD_BANTOTAL psa007dt --'Tipo doc';

                  ,
                   TRIM(PAI_PSA.FU_OBT_SAL_CLI(p.COD_PERSONA, 'E')) psa007eg --'Egreso mensual';

                  ,
                   TRIM(fug_es_empleado(p.cod_persona)) psa007em --'Empleado';

                   --,TRIM(pai_psa.fu_obt_est_civil(p.cod_persona, p.TIPO)) psa007es --'Estado civil';

                  ,
                   DECODE(PAMEC.VAL_COD_BANTOTAL, '999', 7, PAMEC.VAL_COD_BANTOTAL) psa007es --'Estado civil';

                  ,
                   TRIM(TO_CHAR(p.fec_modificacion, 'YYYYMMDD')) psa007fa --'Fecha de actualizacion de datos';
                  ,
                   '17530101' psa007fp --'Fecha fin PEP';

                   --,TRIM(TO_CHAR(PAI_PSA.FU_OBT_FEC_ING_CLIENTE(p.COD_PERSONA),'YYYYMMDD')) psa007fr --'Fecha alta';

                  ,
                   TO_CHAR(cli.fec_ingreso, 'YYYYMMDD') psa007fr --'Fecha alta';

                   /*,TRIM(decode(p.tipo, 'F',
                   (select a.cod_sexo
                       from ba_per_fisicas a
                      where a.cod_persona = p.cod_persona
                        and rownum = 1), null)) psa007ge --'Sexo';*/

                  ,
                   pf.cod_sexo psa007ge --'Sexo';
                  ,
                   TRIM(FUG_OBT_ING_CLIENTE(p.cod_persona, p.tipo)) psa007im --'Salario mensual';
                  ,
                   TO_TIMESTAMP(to_char(cli.fec_ingreso, 'rrrr-MM-DD HH24:MI:SS'),
                                'YYYY-MM-DD HH24:MI:SS') psa007in --'Fecha de ingreso en sistema';
                  ,
                   '17530101' psa007ip --'Fecha inicio PEP';
                  ,
                   lpad(pf.seg_nombre, 25) psa007n2 --'Segundo nombre';
                   --,TRIM(PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_pais, 'BA_PAISES')) psa007na --'Nacionalidad';

                  ,
                   PAMPA.VAL_COD_BANTOTAL psa007na --'Nacionalidad';

                   --,TRIM(TO_CHAR(PAI_PSA.FU_OBT_FEC_NACIMIENTO(p.COD_PERSONA, p.TIPO),'YYYYMMDD')) psa007nc --'Fecha de constitucion/Nacimiento';
                  ,
                   TO_CHAR(DECODE(P.TIPO, 'F', PF.FEC_NACIMIENTO, 'J', PJ.FEC_APERTURA),
                           'YYYYMMDD') psa007nc --'Fecha de constitucion/Nacimiento';
                   /*,TRIM(decode(p.tipo, 'F',
                   PAI_PSA.FU_OBT_COD_BTL_PSA((select a.cod_profesion
                                                 from ba_per_fisicas a
                                                where a.cod_persona = p.cod_persona
                   */ --and rownum = 1), 'BA_PROFESIONES'), null)) psa007oc --'Ocupacion';
                  ,
                   pampr.val_cod_bantotal psa007oc --'Ocupacion';

                   /*,(select a.fon_otros
                    from cr_inf_fondos a
                   where a.cod_persona = p.cod_persona
                     and rownum = 1) psa007of --'Origen de los fondos';*/

                  ,
                   CRF.FON_OTROS psa007of --'Origen de los fondos';
                  ,
                   0             psa007os --'ROS';
                   --,TRIM(PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_pais, 'BA_PAISES')) psa007pa --'Pais';

                  ,
                   PAMPA.VAL_COD_BANTOTAL psa007pa --'Pais';

                   --,TRIM(PAI_PSA.FU_OBT_PEP(p.COD_PERSONA)) psa007pe --'PEP';

                  ,
                   DECODE(NVL(pep.PEP, 'N'), 'N', 'N', 'Y') psa007pe --'PEP';

                  ,
                   0 psa007pf --'Profesion';
                   /*,decode(p.tipo, 'F',
                   PAI_PSA.FU_OBT_COD_BTL_PSA((select a.cod_pai_nacionalidad
                                                 from ba_per_fisicas a
                                                where a.cod_persona = p.cod_persona
                                                  and rownum = 1), 'BA_PAISES'), null) psa007pn --'Pais de Nacimiento';
                   */,
                   PAMPA.VAL_COD_BANTOTAL psa007pn --'Pais de Nacimiento';

                   /*,decode(p.tipo, 'F',
                   PAI_PSA.FU_OBT_COD_BTL_PSA((select a.cod_pais
                                                 from ba_direcciones a
                                                where a.cod_persona = p.cod_persona
                                                  and a.principal = 'S'
                                                  and rownum = 1), 'BA_PAISES'), null) psa007pr --'Pais de la residencia';
                   */,
                   PAMPAR.VAL_COD_BANTOTAL psa007pr --'Pais de la residencia';
                  ,
                   p.TIPO                  psa007pt --'Tipo cliente';
                   --,PAI_PSA.FU_OBT_SAL_CLI(p.COD_PERSONA, 'P') psa007pv --'Total de pasivo';

                  ,
                   NVL(SAL.TOT_PASIVO, 0) psa007pv --'Total de pasivo';

                  ,
                   1 psa007re --'Region'; TODO
                  /*,
                   decode((FUE_OBT_ARL_CLI(p.COD_PERSONA)),
                          'BAJO',
                          1,
                          'MEDIO',
                          2,
                          'ALTO',
                          3,
                          0) psa007ri --'Riesgo';*/
                 -- ,to_number(substr(FUE_OBT_ARL_CLI(p.COD_PERSONA),1,instr(FUE_OBT_ARL_CLI(p.COD_PERSONA),'-',1)-1)) psa007ri --'Riesgo';
                  ,FU_OBT_RIE_CLIENTE(pampa.val_cod_bantotal, pamtd.val_cod_bantotal, p.nro_documento)psa007ri --'Riesgo';

                   /*,TRIM(lpad(DECODE(p.TIPO, 'J', p.NOM_COMPLETO, 'F',
                   UPPER(PAI_PSA.FU_OBT_DES_ACTIVIDAD(p.COD_PERSONA, p.TIPO))), 70)) psa007rs --'Nombre de la empresa';
                   */

                  ,
                   TRIM(lpad(DECODE(p.TIPO, 'J', p.NOM_COMPLETO, 'F', UPPER(PROF.DESCRIPCION)),
                             70)) psa007rs --'Nombre de la empresa';

                  ,
                   'N' psa007sl --'OSL';TODO
                  ,
                   TRIM(PAI_PSA.FU_OBT_TEL_PRINCIPAL(p.COD_PERSONA, 'A')) psa007ta --'Telefonos Adicionales';
                  ,
                   0 psa007te --'Tipo de actividad economica'; TODO
                  ,
                   TRIM(PAI_PSA.FU_OBT_TEL_PRINCIPAL(p.COD_PERSONA, 'P')) psa007tp --'Telefono principal';
                  ,
                   NVL(TO_CHAR(v.fec_vto_documento, 'YYYYMMDD'), '17530101') psa007vd --'Vencimiento del documento';*/
                  ,
                   'B' --BANCO REMITENTE

                    from --MI_CLI_PSAML t
                         (select distinct a.cod_persona
                            from GE_CTA_IMP_PSAML a

                           WHERE A.EXI_ENBANTOTAL = 'N') T,
                         GE_CLIENTES cli,
                         BA_PERSONAS p,
                         ba_per_documentos v
                         --
                        ,
                         CR_INF_FONDOS    pep,
                         BA_PER_FISICAS   PF,
                         BA_PER_JURIDICAS PJ
                         --CIUDAD RESIDENCIA
                        ,
                         BA_CIUDADES    CR,
                         BA_DIRECCIONES DR
                         --CIUDAD LABORAL
                         -- ,
                         --BA_CIUDADES    Cl,
                         -- BA_DIRECCIONES Dl
                         --DEPARTAMENTO
                        ,
                         MI_TAB_PARAMETRICAS PAMD
                         --DIRECCION PARTICULAR
                         --,
                         -- BA_DIRECCIONES DIRP
                         --TIP DOCUMENTO
                        ,
                         MI_TAB_PARAMETRICAS PAMTD
                         --EST CIVIL
                        ,
                         MI_TAB_PARAMETRICAS PAMEC
                         --PAISES
                        ,
                         MI_TAB_PARAMETRICAS PAMPA
                         --PAIS RESIDENCIA
                        ,
                         MI_TAB_PARAMETRICAS PAMPAR
                         --PROFESIONES
                        ,
                         MI_TAB_PARAMETRICAS PAMPR
                         --FONDOS
                        ,
                         CR_INF_FONDOS CRF

                        ,
                         BA_PROFESIONES PROF
                         --TOTAL ACTIVO Y PASIVO
                        ,
                         MI_PSA_CLI_SALDOS SAL

                   where /*t.cod_persona = 413254
                                                                  and */
                   t.cod_persona = cli.cod_persona
                  -- AND T.ES_CLI_BANTOTAL ='N'
                  --and  p.nro_documento IN ('4547116','80053752-1')
                   and cli.cod_persona = p.cod_persona
                   and p.cod_persona = v.cod_persona(+)
                   and p.nro_documento = v.nro_documento(+)
                   and p.cod_tip_documento = v.cod_tip_documento(+)
                  --
                  --PEP
                   and p.cod_persona = pep.cod_persona(+)

                  --PER FIÍSICA Y JURÍDICA
                   AND P.COD_PERSONA = PF.COD_PERSONA(+)
                   AND P.COD_PERSONA = PJ.COD_PERSONA(+)

                  --CIUDAD RESIDENCIA
                   AND P.COD_PERSONA = DR.COD_PERSONA(+)
                   AND DR.COD_CIUDAD = CR.COD_CIUDAD(+)
                   AND DR.COD_PAIS = CR.COD_PAIS(+)
                   AND DR.PRINCIPAL(+) = 'S'

                  --CIUDAD lABORAL
                  /*AND P.COD_PERSONA = DL.COD_PERSONA(+)
                  AND DL.COD_CIUDAD = CL.COD_CIUDAD(+)
                  AND DL.COD_PAIS = CL.COD_PAIS(+)
                  AND DL.TIPO(+) = 'L'*/

                  --DEPARTAMENTO
                   AND PAMD.NOM_TAB_ITGF(+) = 'BA_DEPARTAMENTOS'
                   AND PAMD.VAL_COD_ITGF(+) = CR.COD_DEPARTAMENTO

                  --DIRECCION PARTICULAR
                  /*AND P.COD_PERSONA = DIRP.COD_PERSONA
                  AND DIRP.TIPO = 'P'
                  AND DIRP.PRINCIPAL = 'S'--por la duplicación de clientes*/

                  --TIP DOCUMENTO BANTOTAL
                   AND PAMTD.NOM_TAB_ITGF(+) = 'BA_TIP_DOCUMENTOS'
                   AND PAMTD.VAL_COD_ITGF(+) = P.COD_TIP_DOCUMENTO

                  --EST CIVIL BANTOTAL
                   AND PF.EST_CIVIL = PAMEC.VAL_COD_ITGF(+)
                   AND 'BA_COD_REFERENCIAS' = PAMEC.NOM_TAB_ITGF(+)
                   AND 'COD_EST_CIVIL' = PAMEC.DOM_REF_ITGF(+)

                  --PAISES
                   AND PAMPA.NOM_TAB_ITGF(+) = 'BA_PAISES'
                   AND PAMPA.VAL_COD_ITGF(+) = nvl(p.cod_pai_documento,P.COD_PAIS)

                  --PAIS RESIDENCIA
                   AND PAMPAR.NOM_TAB_ITGF(+) = 'BA_PAISES'
                   AND PAMPAR.VAL_COD_ITGF(+) = DR.COD_PAIS

                  --PROFESIONES
                   AND PAMPR.NOM_TAB_ITGF(+) = 'BA_PROFESIONES'
                   AND PAMPR.VAL_COD_ITGF(+) = PF.COD_PROFESION

                  --FONDOS
                   AND P.COD_PERSONA = CRF.COD_PERSONA(+)

                  --PROFESIONES
                   AND PF.COD_PROFESION = PROF.COD_PROFESION(+)

                  --TOTAL ACTIVO Y PASIVO
                   AND P.COD_PERSONA = SAL.COD_PERSONA(+)

                  --
                   AND (TRUNC(CLI.FEC_INSERCION) <= TRUNC(P_FEC_PROCESO) OR
                   TRUNC(CLI.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO))
                   AND NOT EXISTS (SELECT 'S'
                      FROM PSA007 A7
                     WHERE A7.PSA007PA = PAMPA.VAL_COD_BANTOTAL
                       AND A7.PSA007DT = PAMTD.VAL_COD_BANTOTAL
                       AND A7.PSA007DO = p.nro_documento)
                   --Generar todos los clientes 
                   /*and exists (select 'S'
                               FROM PSA006 cue
                               WHERE cue.psa006pa = pampa.val_cod_bantotal
                               and   cue.psa006td = pamtd.val_cod_bantotal
                               and   cue.psa006do = p.nro_documento)*/;

               


         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20000,
                                       'Error al ejecutar la creacion del archivo ' || v_nom_archivo ||
                                        sqlerrm);
         END;


         --actualización masiva fecha ingreso cliente
       begin
          update psa007 t
             set t.psa007fr = TO_CHAR(TO_DATE('01/01/2001', 'MM/DD/YYYY'),
                                      'YYYYMMDD')
           where TO_dATE(t.psa007fr, 'RRRRMMDD') <
                 TO_DATE('01/01/1950', 'dd/mm/yyyy')
              or (TO_NUMBER(TO_CHAR(TO_dATE(t.psa007fr, 'RRRRMMDD'), 'YYYY')) >
                  TO_NUMBER(TO_CHAR(SYSDATE, 'YYYY')));
       exception
          when others then
             raise_application_error(-20000,
                                     'Error al actualizar datos de productos: ' ||
                                     sqlerrm);
       end;
       commit;
   end;

   -- Archivo de Cuentas
   PROCEDURE PR_GEN_ARC_CUENTAS(P_FEC_PROCESO IN DATE) IS
   BEGIN

      BEGIN
         IF V_REPROCESO = 'S' THEN
             delete psa006 t
             where exists (select 's'
                      from (SELECT C.COD_PERSONA, c.fec_proceso
                              FROM GE_CTA_IMP_PSAML C) ct,
                           BA_PERSONAS P
                     WHERE Ct.COD_PERSONA = P.COD_PERSONA
                       AND Ct.FEC_PROCESO = P_FEC_PROCESO
                       AND p.nro_documento = t.Psa006do
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,
                                                          p.cod_pais),
                                                      'BA_PAISES') =
                           t.Psa006pa
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento,
                                                      'BA_TIP_DOCUMENTOS') =
                           t.Psa006td);
         END IF;
      END;


      PR_PRE_PRO_REGISTROS('PSA006',SYSDATE,V_REPROCESO);

      begin
         insert into psa006
            (PSA006PA,
             PSA006TD,
             PSA006DO,
             PSA006MO,
             PSA006CT,
             PSA006SO,
             PSA006ST,
             PSA006FC,
             PSA006CP,
             PSA006LT,
             PSA006FO,
             PSA006EJ,
             PSA006BC,
             PSA006NC,
             PSA006CO,
             PSA006TF,
             PSA006BR)--BANCO REMITENTE
             SELECT *
             FROM( SELECT PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per.cod_pai_documento,per.cod_pais), 'BA_PAISES') PSA006PA --Pais
                  ,PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_tip_documento, 'BA_TIP_DOCUMENTOS') PSA006TD --Tipo de documento
                  ,per.nro_documento PSA006DO --Documento
                  ,PAI_PSA.FU_OBT_COD_BTL_PSA(CTA.cod_modulo, CTA.cod_modalidad, 'MODULOS_PRODUCTOS') PSA006MO --Cod Producto BT
                  --,7||lpad(per.cod_persona,8,0) PSA006CT --lpad(cta.nro_cuenta, 9) PSA006CT --Cuenta N°
                  ,MCT.NRO_CTA_BANTOTAL PSA006CT
                  /*cuenta ficticia generada para la migración temporal de los datos de psa006*/
                  --,9||lpad(per.cod_persona,6,0)||substr(CTACLI.Nro_Cuenta,-2) PSA006CT
                  --,pai_psa.FU_OBT_NRO_SUB_OPERACION(per.cod_persona, ctacli.nro_cuenta) PSA006SO --Sub Operacion
                  ,MCT.NRO_SUB_CTA_BANTOTAL PSA006SO --Sub Operacion
                  --,0 PSA006ST --Estado (NORMAL O ACTIVA)
                  --,PAI_PSA.FU_OBT_COD_BTL_PSA(cta.estado,'GE_EST_CUENTAS') PSA006ST --Estado (NORMAL O ACTIVA)
                  ,DECODE(EC.ACTIVO,'S',0,99) PSA006ST --Estado (NORMAL O ACTIVA)
                  ,TO_CHAR(CTA.FEC_APERTURA,'rrrrMMDD') PSA006FC --Fecha de creacion
                  ,0 PSA006CP --Codigo producto
                  ,(case
                     when ctacli.cod_modulo = 5 then
                     nvl(( select l.lin_credito
                           from ta_cta_tarjetas l
                           where l.nro_cuenta = ctacli.nro_cuenta),0)
                     else
                      0
                   end) PSA006LT --Limite de TC
                  ,TO_TIMESTAMP(TO_CHAR(CLI.fec_ingreso ,'rrrr-MM-DD HH24:MI:SS'), 'YYYY-MM-DD HH24:MI:SS')  PSA006FO --Fecha y hora de ingraso
                  ,PSA.COD_OFI_BANTOTAL PSA006EJ
                  ,PAI_PSA.FU_OBT_COD_BTL_PSA(cli.cod_seg_cliente,'GE_SEG_CLIENTES') PSA006BC --Banca
                  ,trim(lpad(REPLACE(CTA.DENOMINACION, CHR(10), ' '), 70)) PSA006NC --Nombre cuenta
                  ,decode(ctacli.relacion,'P',1,2) PSA006CO --Codigo Titular
                  ,decode(ctacli.relacion,'P','T','') PSA006TF --Titular Firmante
                  ,'B'--BANCO REMITENTE
                  --,CTA.FEC_APERTURA FPSA006FC
                  --,cli.fec_ingreso FPSA006FO
              FROM GE_CTA_CLIENTES CTACLI
                  ,GE_CUENTAS      CTA
                  ,GE_CLIENTES     CLI
                  ,ba_personas     per
                  ,GE_CTA_IMP_PSAML PSA
                  ,GE_EST_CUENTAS EC
                  ,MI_CTA_CLIENTES MCT
             WHERE CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
               AND CTACLI.COD_PERSONA = CLI.COD_PERSONA

               --
               AND MCT.NRO_CTA_ITGF = CTACLI.NRO_CUENTA
               AND MCT.COD_PERSONA = CTACLI.COD_PERSONA
               --
               --AND CTACLI.RELACION = 'P'
               and cli.cod_persona = per.cod_persona
               AND (TRUNC(CLI.FEC_INSERCION) <= P_FEC_PROCESO OR
                   TRUNC(CLI.FEC_MODIFICACION) = P_FEC_PROCESO)
                  --and CTACLI.cod_persona = 391015
               AND CTACLI.NRO_CUENTA = PSA.NRO_CUENTA
               AND CTACLI.COD_PERSONA = PSA.COD_PERSONA
               AND CTA.COD_MODULO = EC.COD_MODULO
               AND CTA.COD_MODALIDAD = EC.COD_MODALIDAD
               AND CTA.ESTADO = EC.ESTADO)CTAS_PSAML
               WHERE NOT EXISTS (SELECT 'S' FROM PSA006 A6
                                  WHERE A6.PSA006PA = CTAS_PSAML.PSA006PA-- PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_pais, 'BA_PAISES')
                                   AND A6.PSA006TD = CTAS_PSAML.PSA006TD--PAI_PSA.FU_OBT_COD_BTL_PSA(per.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                                   AND A6.PSA006DO = CTAS_PSAML.PSA006DO--per.nro_documento
                                   AND A6.PSA006MO = CTAS_PSAML.PSA006MO--PAI_PSA.FU_OBT_COD_BTL_PSA(CTA.cod_modulo, CTA.cod_modalidad, 'MODULOS_PRODUCTOS')
                                   AND A6.PSA006CT = CTAS_PSAML.PSA006CT--7||lpad(per.cod_persona,8,0)
                                   AND A6.PSA006SO = CTAS_PSAML.PSA006SO)--pai_psa.FU_OBT_NRO_SUB_OPERACION(per.cod_persona, ctacli.nro_cuenta));
                --SOLO LOS QUE TUVIERON MOVIMIENTOS EN LA FECHA DE PROCESO
                and exists (select 'S'
                            FROM PSA003 MOV
                            WHERE MOV.psa003nc = CTAS_PSAML.PSA006CT
                            AND   TO_dATE(MOV.psa003ft, 'RRRRMMDD') = P_FEC_PROCESO);
      exception
         when others then
            raise_application_error(-20000, 'Error insertar datos de productos: ' || sqlerrm);
      end;
      --ajuste masivo de fechas de ingreso mal cargados en el core itgf
      begin
         update psa006 t
            set t.psa006fo = TO_TIMESTAMP('1753-01-01 10:00:00',
                                          'YYYY-MM-DD HH24:MI:SS')-- se le asigna el dato menor posible
          where t.psa006fo <=
                TO_TIMESTAMP(TO_CHAR(to_date('01/01/1753', 'dd/mm/rrrr'),
                                     'rrrr-MM-DD HH24:MI:SS'),
                             'YYYY-MM-DD HH24:MI:SS');
       exception
          when others then
          raise_application_error(-20000, 'Error al actualizar datos de productos: ' || sqlerrm);
       end;

       --commit;

   END;

   -- Archivo de Relaciones de clientes cuentas
   PROCEDURE PR_GEN_ARC_RELACIONES(P_FEC_PROCESO IN DATE) IS

   BEGIN
      PR_PRE_PRO_REGISTROS('PSA004',SYSDATE,V_REPROCESO);
      INSERT INTO PSA004 --Relaciones
         (psa004co, --csConsecutivointerno
          psa004cv, --Codigo Vinculo
          psa004da, --Documento A
          psa004db, --Documento B
          psa004er, --Estado de la relacion
          psa004pa, --Pais A
          psa004pb, --Pais B
          psa004ta, --Tipo doc A
          psa004tb, --Tipo doc B
          PSA004BR) --BANCO REMITENTE
         Select distinct 0 PSA004CO
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(v.tipo, 'BA_TIP_VINCULOS') tipo
               ,per_a.nro_documento documento_a
               ,per_b.nro_documento documento_b
               ,'A' estado_relacion
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per_a.cod_pai_documento,per_a.cod_pais), 'BA_PAISES') pais_a_bt
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per_b.cod_pai_documento,per_b.cod_pais), 'BA_PAISES') pais_b_bt
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(per_a.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_doc_a_bt
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(per_b.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_doc_b_bt
               ,'B'--banco remitente
           from ba_vinculos       v
               ,ba_personas       per_a
               ,ba_personas       per_b
               ,ba_tip_documentos td_a
               ,ba_tip_documentos td_b
               ,BA_TIP_VINCULOS   tv
               ,GE_CTA_IMP_PSAML  cli

          where per_a.cod_persona = v.cod_persona
            and per_b.cod_persona = v.cod_per_vinculo

            and per_a.cod_tip_documento = td_a.cod_tip_documento
            and per_b.cod_tip_documento = td_b.cod_tip_documento

            and v.tipo = tv.cod_tip_vinculo

            and cli.cod_persona = v.cod_persona
            AND CLI.EXI_ENBANTOTAL = 'N'
            and cli.fec_proceso >= P_FEC_PROCESO
            and not exists (select 'S'
                            FROM PSA004 A
                            WHERE A.PSA004PA = PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per_a.cod_pai_documento,per_a.cod_pais), 'BA_PAISES')
                              AND A.PSA004TA = PAI_PSA.FU_OBT_COD_BTL_PSA(per_a.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                              AND A.PSA004DA = per_a.nro_documento
                              AND A.PSA004PB = PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(per_b.cod_pai_documento,per_b.cod_pais), 'BA_PAISES')
                              AND A.PSA004TB = PAI_PSA.FU_OBT_COD_BTL_PSA(per_b.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                              AND A.PSA004DB = per_b.nro_documento
                              AND A.PSA004CV = PAI_PSA.FU_OBT_COD_BTL_PSA(v.tipo, 'BA_TIP_VINCULOS'));
   END;

   -- Archivo de perfiles de clientes
   PROCEDURE PR_GEN_ARC_PERFILES(P_FEC_PROCESO IN DATE) IS

   BEGIN
      PR_PRE_PRO_REGISTROS('PSA005',SYSDATE,V_REPROCESO);
      INSERT INTO psa005 --Declaraciones
         (psa005ct, --Cuenta N°
          psa005le, --LOA Entrante
          psa005ls, --Tipo doc B
          psa005br) --banco remitente

          select cli.nro_Cta_bantotal,
          sum(cli.monto_CREDITO) entrada,
          sum(cli.monto_DEBITO) salida,
          'B' banco
     from ( --PRINCIPALES personas físicas
           SELECT distinct mcl.nro_cta_bantotal,
                           FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA, 'GS', ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) monto_CREDITO,
                           FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA, 'GS', ACT.MTO_PRO_DEBITO, NULL, ACT.FECHA) monto_DEBITO,
                            --'B', --BANCO REMITENTE
                            act.cod_persona
             FROM CR_ACT_ESPERADAS ACT,
                   (select distinct a.cod_persona from GE_CTA_IMP_PSAML a) x,
                   ge_cta_clientes cta,
                   mi_cta_clientes mcl,
                   ba_personas p
            WHERE X.COD_PERSONA = ACT.COD_PERSONA
              and cta.cod_persona = mcl.cod_persona
              and cta.nro_cuenta = mcl.nro_cta_itgf
              and act.cod_persona = cta.cod_persona
              and cta.cod_persona = p.cod_persona
              and p.tipo = 'F'
              AND NOT EXISTS
            (SELECT 'S'
                     FROM mi_cta_clientes t,
                          ba_personas     p
                    where t.principal = 'P'
                      and t.cod_persona = p.cod_persona
                      and (p.tipo = 'J' or t.referencia3 = 35)/*tarjetas*/
                      AND T.NRO_CTA_BANTOTAL = MCL.NRO_CTA_BANTOTAL)
              AND ACT.fec_insercion = (SELECT MAX(s.fec_insercion)
                                         FROM CR_ACT_ESPERADAS s
                                        WHERE COD_PERSONA = x.COD_PERSONA
                                          AND (TRUNC(s.FEC_INSERCION) <= P_FEC_PROCESO OR
                                              TRUNC(s.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO)))
              AND (TRUNC(ACT.FEC_INSERCION) <= P_FEC_PROCESO OR
                  TRUNC(ACT.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO))
           UNION ALL
           --EMPRESAS
           SELECT distinct mcl.nro_cta_bantotal,
                            FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA, 'GS', ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) monto,
                            FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA, 'GS', ACT.MTO_PRO_DEBITO, NULL, ACT.FECHA) monto_DEBITO,
                            act.cod_persona
             FROM CR_ACT_ESPERADAS ACT,
                   (select distinct a.cod_persona from GE_CTA_IMP_PSAML a) x,
                   ge_cta_clientes cta,
                   mi_cta_clientes mcl,
                   ba_personas p
            WHERE X.COD_PERSONA = ACT.COD_PERSONA
              and cta.cod_persona = mcl.cod_persona
              and cta.nro_cuenta = mcl.nro_cta_itgf
              and act.cod_persona = cta.cod_persona
              and cta.cod_persona = p.cod_persona
              --and p.tipo = 'J'--EMPRESAS
              and (p.tipo = 'J'/*EMPRESAS*/ or mcl.referencia3 = 35)/*tarjetas*/
              and mcl.principal = 'P'
              AND CTA.RELACION = 'P'
              AND ACT.fec_insercion = (SELECT MAX(s.fec_insercion)
                                         FROM CR_ACT_ESPERADAS s
                                        WHERE COD_PERSONA = x.COD_PERSONA
                                          AND (TRUNC(s.FEC_INSERCION) <= P_FEC_PROCESO OR
                                              TRUNC(s.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO)))
              AND (TRUNC(ACT.FEC_INSERCION) <= P_FEC_PROCESO OR
                  TRUNC(ACT.FEC_MODIFICACION) >= TRUNC(P_FEC_PROCESO))
           
           ) cli
    group by cli.nro_Cta_bantotal;

   END;

   -- Archivo de CATALOGOS
   PROCEDURE PR_GEN_ARC_CATALOGOS  IS

   BEGIN
      begin
         delete PSA001;
      end;

      INSERT INTO PSA001 --Declaraciones
         (psa001ci, --Codigo interno
          psa001co, --codigo
          psa001d1, --descripción
          psa001d2, --descripción adicional
          psa001in, --interfaz
          psa001n1, --valor
          psa001BR --BANCO REMITENTE
          )
         select distinct T.VAL_COD_ITGF Codigo_Interno
                         --,length(t.nom_tab_itgf) + 100 Codigo
                        ,(case
                            when TRANSLATE(t.val_cod_itgf, 'T 0123456789', 'T') is not null then
                             t.val_cod_itgf3
                            else
                             t.val_cod_itgf
                         end) || length(t.nom_tab_itgf) Codigo
                        ,t.descripcion Descripcion
                        ,'ITGF_' || t.nom_tab_itgf Descripcion_Adicional
                        ,991 Interfaz
                        ,0 Valor
                        ,'B'
           from mi_tab_parametricas t
          where t.val_cod_bantotal in ('#N/A', 'N/A', '')
            and t.nom_tab_itgf NOT IN ('BA_CIUDADES', 'BA_BARRIOS', 'GE_EST_CUENTAS');
   END;

   PROCEDURE PR_GEN_ARC_LIS_CLIENTE(P_FEC_PROCESO IN DATE) IS
   BEGIN
      IF V_REPROCESO = 'S' THEN
         begin
            delete psa002 t
             where exists (select 's'
                      from (SELECT C.COD_PERSONA, c.fec_proceso
                              FROM GE_CTA_IMP_PSAML C
                             WHERE C.EXI_ENBANTOTAL = 'N') ct,
                           BA_PERSONAS P
                     WHERE Ct.COD_PERSONA = P.COD_PERSONA
                       AND Ct.FEC_PROCESO = P_FEC_PROCESO
                       AND p.nro_documento = t.psa002do
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,
                                                          p.cod_pais),
                                                      'BA_PAISES') =
                           t.psa002pa
                       and PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento,
                                                      'BA_TIP_DOCUMENTOS') =
                           t.psa002to);
         end;
      END IF;

      PR_PRE_PRO_REGISTROS('PSA002',SYSDATE,V_REPROCESO);
      INSERT INTO PSA002
         (PSA002CL,
          PSA002DO,
          PSA002FB,
          PSA002FS,
          PSA002PA,
          PSA002TO,
          PSA002BR)
         SELECT * FROM (Select /*distinct decode(pa.val_cod_bantotal, 'N/A', PA.VAL_COD_ITGF, pa.val_cod_bantotal) cod_lista*/
                        pa.val_cod_bantotal cod_lista
                        ,p.nro_documento
                        --,TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') fec_ing_psaml
                        ,'17530101' fec_ing_psaml --FECHA NULL VALOR POR DEFECTO
                        --,p.fec_insercion PSA002FS
                        ,TO_CHAR(p.fec_insercion,'RRRRMMDD') PSA002FS
                        ,PAI_PSA.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento,p.cod_pais), 'BA_PAISES') cod_pais
                        ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tpdoc
                        ,'B'--INDICA QUE EL DATO ES DEL SISTEMA ITGF
                        --,TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') fec_ing_psaml
                        --,p.fec_insercion PSA002FS
           from (select distinct  a.cod_persona
                         /*,max(a.cod_causa)*/ ,180 cod_causa
                   from GE_PER_INHIBIDAS a
                   WHERE  NOT EXISTS( SELECT 'S'
                                      FROM GE_CTA_IMP_PSAML S
                                      WHERE S.COD_PERSONA = A.COD_PERSONA
                                      AND   S.EXI_ENBANTOTAL ='S')
                    and (a.fec_insercion <= P_FEC_PROCESO
                        or a.fec_modificacion = P_FEC_PROCESO)
                        /*group by a.cod_persona*/) T
               ,mi_tab_parametricas pa
               ,ba_personas p
          where pa.nom_tab_itgf = 'GE_PER_CAUSALES'
            AND Pa.VAL_COD_ITGF = T.COD_CAUSA
            and p.cod_persona = t.cod_persona)LIS

            where pai_psa.FU_CLI_EXI_ENBANTOTAL(LIS.cod_pais,LIS.tpdoc,LIS.nro_documento) = 'N'

            --NO ENVIAR LO YA EXISTENTE
            and NOT EXISTS (SELECT 'S'
                            FROM PSA002 A
                            WHERE A.PSA002CL = LIS.cod_lista -- decode(pa.val_cod_bantotal, 'N/A', PA.VAL_COD_ITGF, pa.val_cod_bantotal)
                              AND A.PSA002PA = LIS.cod_pais--PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_pais, 'BA_PAISES')
                              AND A.PSA002TO = LIS.tpdoc --PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS')
                              AND A.PSA002DO = LIS.nro_documento);--p.nro_documento);

   END;

   PROCEDURE PR_GEN_ARC_USER_DEFINED(P_FEC_PROCESO IN DATE) IS
      V_FILE UTL_FILE.FILE_TYPE;
      V_PATH VARCHAR2(200) := 'ASSIST';
      V_TIPO VARCHAR2(1) := 'w'; -- w-reemplazar / a-agregar

      cursor C_CAMPOS IS --clientes frecuentes y gestores de clientes
         SELECT distinct RPAD(CTACLI.COD_PERSONA, 20, ' ') || --cod_cliente
                         RPAD('FRECUENTE', 40, ' ') || --LABEL
                         RPAD(decode(f.cli_frecuente, 'S', 'SI', 'N', 'NO', 'NO'), 200, ' ') CADENA

           FROM GE_CTA_CLIENTES CTACLI
               ,GE_CLIENTES     CLI
               ,BA_PERSONAS     PER
               ,cr_inf_fondos   f
          WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
            AND CTACLI.COD_PERSONA = PER.COD_PERSONA
            and CTACLI.COD_PERSONA = f.cod_persona(+)
            AND (TRUNC(CLI.FEC_INSERCION) <= P_FEC_PROCESO OR
                TRUNC(CLI.FEC_MODIFICACION) = P_FEC_PROCESO)
            AND EXISTS (SELECT 1
                   FROM GE_CTA_IMP_PSAML X
                  WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                    AND X.COD_PERSONA = CTACLI.COD_PERSONA)

         UNION ALL

         SELECT DISTINCT replace((RPAD(CTACLI.COD_PERSONA, 20, ' ') || RPAD('GESTOR', 40, ' ') ||
                                 RPAD(BU.NOMBRE, 200, ' ')), chr(10), ' ') CADENA

           FROM GE_CTA_CLIENTES CTACLI
               ,GE_CLIENTES     CLI
               ,BA_PERSONAS     PER
               ,BA_USUARIOS     BU
          WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
            AND CTACLI.COD_PERSONA = PER.COD_PERSONA
            AND CLI.COD_USU_OFICIAL = BU.COD_USUARIO
            AND (TRUNC(CLI.FEC_INSERCION) <= P_FEC_PROCESO OR
                TRUNC(CLI.FEC_MODIFICACION) = P_FEC_PROCESO)
            AND EXISTS (SELECT 1
                   FROM GE_CTA_IMP_PSAML X
                  WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                    AND X.COD_PERSONA = CTACLI.COD_PERSONA);

   BEGIN
      -- Nombre del Archivo.
      V_NOM_ARCHIVO := 'FC' || TO_CHAR(P_FEC_PROCESO, 'YYYYMMDD') || '.TXT';
      -- Detalle
      -- Generar archivo
      IF UTL_FILE.IS_OPEN(V_FILE) = FALSE THEN
         V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
      END IF;

      -- Detalle
      FOR F_CURSOR IN C_CAMPOS LOOP
         UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
      END LOOP;

      -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
      --
   END;

   -- Archivo de Transacciones (movimientos) de cuentas de clientes
   PROCEDURE PR_REGEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE) IS
      /* TENER EN CUENTA ESTE MOVIMIENTO PARA AJUSTAR EL PROCESO
         utilizar el cod persona para la ponerlo en nro de cuenta psaml
         y subcuenta un nro a consultar.
      Select *
        from gv_movimientos t
       where t.COD_TRA_PADRE = 250
         and t.COD_MOD_PADRE = 7
         AND t.FECHA = to_date('10/03/2021', 'dd/mm/rrrr')
         and t.HORA = '10:01:54'*/

      v_cotizacion_usd GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('USD',
                                                                                 P_FEC_PROCESO);
      v_cotizacion_eur GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('EUR',
                                                                                 P_FEC_PROCESO);
      v_redondeo       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                                                  null, null, 'USD');
   begin
      IF V_REPROCESO = 'S' THEN
         BEGIN
            --SE BORRA LOS REGISTROS DE LA TABLA
            DELETE PSA003 T WHERE TO_dATE(T.PSA003FT, 'RRRRMMDD') = P_FEC_PROCESO;
         END;
         --commit;
      END IF;



      PR_PRE_PRO_REGISTROS('PSA003',SYSDATE,V_REPROCESO);
      PR_LOG_PSAML('PR_REGEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTOS NORMALES');
     --MOVIMIENTOS NORMALES
     BEGIN
      insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
         SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,TRIM(movi.nro_bin) psa003bi --csbin
               ,TRIM(movi.nro_canal) psa003ca --cscanaltrx
               ,TRIM(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,TRIM(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,TRIM(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,TRIM(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,TRIM(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               ,modcta.modulo psa003ct
               ,TRIM(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,TRIM(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,TRIM(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,TRIM(MOVI.MONTO) psa003dl --cmmonto dolares
               ,TRIM(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,TRIM(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,TRIM(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,TRIM(MOVI.CAJERO) psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,TRIM(movi.cotizacion_origen) psa003md -- moneda origen
               ,TRIM(movi.moneda_local) psa003ml --cmmonto moneda local
               ,TRIM(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,TRIM(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               ,MOVI.NRO_CTA_BANTOTAL psa003nc --csnumerocuenta
               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES') psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,TRIM(movi.referencia) psa003rf --referencia
               ,/*PK*/ (999999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,TRIM(pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta)) psa003so --sub operación
               ,MOVI.NRO_SUB_CTA_BANTOTAL psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,TRIM(movi.tip_per_documento) psa003td --tipo doc
               ,TRIM(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,TRIM(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion

           FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       , pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,
                        -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
                        MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       /*,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            nvl((select tdd.nro_tarjeta
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1),P.NRO_DOCUMENTO)
                           when mov.cod_usuario not like 'ATM%' then
                            p.nro_documento
                           else
                            null
                        end) nro_tarjeta_documento*/
                       , p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                       , MCL.NRO_CTA_BANTOTAL
                       , MCL.NRO_SUB_CTA_BANTOTAL
                   FROM Gv_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       ,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                       ,MI_CTA_CLIENTES MCL
                  WHERE mov.nro_cuenta = c.nro_cuenta
                    and c.cod_persona = p.cod_persona
                    AND C.RELACION = 'P'
                    --
                    AND MOV.NRO_CUENTA = MCL.NRO_CTA_ITGF
                    AND P.COD_PERSONA = MCL.COD_PERSONA
                    --
                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)
                       /*AND (ATR.cod_modulo in (3, 4, 6) OR
                       (ATR.cod_modulo = 9 AND ATR.cod_mod_padre in (3, 4, 6)))*/

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO
                       --and fecha = to_date('19/02/2021', 'DD/MM/YYYY')
                       --AND TRUNC(FECHA) = PAI_PSA.FU_OBT_FEC_PROCESO
                       --para el control de transferencias HBank a terceros

                       --COMENTADO PARA PSAML
                    /*AND ((ATR.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I') AND
                        MOV.COD_USUARIO = 'HBANK' AND (INSTR(MOV.CONCEPTO, 'Transf. a', 1, 1) > 0 AND
                        INSTR(MOV.CONCEPTO, ' desde ', 1, 1) > 0 OR
                        (MOV.CONCEPTO = 'Pago de Sueldo ') OR
                        (MOV.CONCEPTO = 'Pago de Aguinaldo '))) OR
                        (ATR.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I') OR
                        MOV.COD_USUARIO != 'HBANK'))*/
                      --COMENTADO PARA PSAML

                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI, (select distinct ctx.nro_cta_bantotal,
                                          ctx.referencia3 modulo
                                     from mi_cta_clientes ctx)modcta
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA)
            
            and movi.NRO_CTA_BANTOTAL = modcta.nro_cta_bantotal
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                )

             --Solamente los Productos PRO-21-GS, PRO-21-ME, PRO-20-GS,
             --PRO-20-ME, PRO-22-GS y PRO-22-ME. Consideramos como creditos y debitos,
             --por tanto, los demás productos solo consideramos como Creditos.
                and  ((modcta.modulo not in (20,21,22)
                      and decode(MOVI.TIPO, 'D', 1, 2) = 2)--mov crédito
                      or (modcta.modulo in (20,21,22))
                     );
      END;

      PR_LOG_PSAML('PR_REGEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTO EFECTIVO X EFECTIVO EN CAJA');
     --MOVIMEINTO EFECTIVO X EFECTIVO EN CAJA (POR EJ COMPRA DE DIVISAS)
     BEGIN
        insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
          SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,trim(movi.nro_bin) psa003bi --csbin
               ,trim(movi.nro_canal) psa003ca --cscanaltrx
               ,trim(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,trim(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,trim(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,trim(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,trim(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               --,modcta.modulo psa003ct
               ,20 psa003ct --(cuenta corriente )valor por defecto para operaciones de efectivo en caja
               ,trim(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,trim(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,trim(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,trim(MOVI.MONTO) psa003dl --cmmonto dolares
               ,trim(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,trim(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,trim(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,MOVI.CAJERO psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,trim(movi.cotizacion_origen) psa003md -- moneda origen
               ,trim(movi.moneda_local) psa003ml --cmmonto moneda local
               ,trim(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,trim(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               /*,(SELECT MCL.NRO_CTA_BANTOTAL
                 FROM MI_CTA_CLIENTES MCL
                 WHERE MCL.COD_PERSONA = MOVI.COD_PERSONA
                 AND MCL.PRINCIPAL = 'P' AND ROWNUM = 1)psa003nc --csnumerocuenta*/

               ,nvl((SELECT MCL.NRO_CTA_BANTOTAL
                     FROM MI_CTA_CLIENTES MCL
                    WHERE MCL.COD_PERSONA = MOVI.cod_persona
                      AND MCL.PRINCIPAL = 'P'
                      AND ROWNUM = 1),
                   (SELECT MCL.NRO_CTA_BANTOTAL
                      FROM MI_CTA_CLIENTES MCL
                     WHERE MCL.COD_PERSONA = MOVI.cod_persona
                       AND MCL.PRINCIPAL = 'N'
                       AND ROWNUM = 1))psa003nc --csnumerocuenta

               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,trim(PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES')) psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,trim(movi.referencia) psa003rf --referencia
               ,/*PK*/ (999999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta) psa003so --sub operación
               ,1 psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,trim(movi.tip_per_documento) psa003td --tipo doc
               ,trim(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,trim(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion
               --,TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') FPSA003FI
               --,movi.fec_valor FPSA003FT
               --,movi.fecha_hora FPSA003HT
               FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       ,pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       ,p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                   FROM GV_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       --,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                  WHERE

                     mov.COD_PERSONA  = p.cod_persona
                    AND MOV.COD_PERSONA IS NOT NULL
                    AND MOV.NRO_CUENTA IS NULL

                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO



                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.COD_PERSONA = MOVI.COD_PERSONA)
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                );
     END;

      PR_LOG_PSAML('PR_REGEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTO PRESTAMOS');
     --movimientos préstamos
     BEGIN
      insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
         SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,TRIM(movi.nro_bin) psa003bi --csbin
               ,TRIM(movi.nro_canal) psa003ca --cscanaltrx
               ,TRIM(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,TRIM(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,TRIM(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,TRIM(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,TRIM(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               ,modcta.modulo psa003ct
               ,TRIM(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,TRIM(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,TRIM(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,TRIM(MOVI.MONTO) psa003dl --cmmonto dolares
               ,TRIM(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,TRIM(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,TRIM(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,TRIM(MOVI.CAJERO) psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,TRIM(movi.cotizacion_origen) psa003md -- moneda origen
               ,TRIM(movi.moneda_local) psa003ml --cmmonto moneda local
               ,TRIM(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,TRIM(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               ,MOVI.NRO_CTA_BANTOTAL psa003nc --csnumerocuenta
               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES') psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,TRIM(movi.referencia) psa003rf --referencia
               ,/*PK*/ (999999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,TRIM(pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta)) psa003so --sub operación
               ,MOVI.NRO_SUB_CTA_BANTOTAL psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,TRIM(movi.tip_per_documento) psa003td --tipo doc
               ,TRIM(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,TRIM(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion

           FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       , pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,
                        -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
                        MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       , p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                       ,substr(MOV.concepto, -10) NRO_CUENTA_PR
                        , MCL.NRO_CTA_BANTOTAL
                       , MCL.NRO_SUB_CTA_BANTOTAL
                   FROM Gv_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       ,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                       ,MI_CTA_CLIENTES MCL
                  WHERE --mov.nro_cuenta = c.nro_cuenta


                    substr(MOV.concepto, -10) = C.NRO_CUENTA
                    and c.cod_persona = p.cod_persona
                    AND C.RELACION = 'P'

                    AND MOV.NRO_CUENTA IS NULL
                    AND MOV.COD_PERSONA IS NULL
                    AND MOV.COD_MOD_PADRE = 6 --préstamos

                     --
                    AND C.NRO_CUENTA = MCL.NRO_CTA_ITGF
                    AND P.COD_PERSONA = MCL.COD_PERSONA
                    --

                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)
                       /*AND (ATR.cod_modulo in (3, 4, 6) OR
                       (ATR.cod_modulo = 9 AND ATR.cod_mod_padre in (3, 4, 6)))*/

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO
                       --and fecha = to_date('19/02/2021', 'DD/MM/YYYY')
                       --AND TRUNC(FECHA) = PAI_PSA.FU_OBT_FEC_PROCESO
                       --para el control de transferencias HBank a terceros

                       --COMENTADO PARA PSAML

                      --COMENTADO PARA PSAML

                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI, (select distinct ctx.nro_cta_bantotal,
                                          ctx.referencia3 modulo
                                     from mi_cta_clientes ctx)modcta
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA)
            
            and movi.NRO_CTA_BANTOTAL = modcta.nro_cta_bantotal
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                )

             --Solamente los Productos PRO-21-GS, PRO-21-ME, PRO-20-GS,
             --PRO-20-ME, PRO-22-GS y PRO-22-ME. Consideramos como creditos y debitos,
             --por tanto, los demás productos solo consideramos como Creditos.
                and  ((modcta.modulo not in (20,21,22)
                      and decode(MOVI.TIPO, 'D', 1, 2) = 2)--mov crédito
                      or (modcta.modulo in (20,21,22))
                     );

      END;

   END;

PROCEDURE PR_GEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE) IS
      /* TENER EN CUENTA ESTE MOVIMIENTO PARA AJUSTAR EL PROCESO
         utilizar el cod persona para la ponerlo en nro de cuenta psaml
         y subcuenta un nro a consultar.
      Select *
        from GE_MOVIMIENTOS t
       where t.COD_TRA_PADRE = 250
         and t.COD_MOD_PADRE = 7
         AND t.FECHA = to_date('10/03/2021', 'dd/mm/rrrr')
         and t.HORA = '10:01:54'*/

      v_cotizacion_usd GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('USD',
                                                                                 P_FEC_PROCESO);
      v_cotizacion_eur GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('EUR',
                                                                                 P_FEC_PROCESO);
      v_redondeo       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                                                  null, null, 'USD');
   begin
      IF V_REPROCESO = 'S' THEN
         BEGIN
            --SE BORRA LOS REGISTROS DE LA TABLA
            DELETE PSA003 T WHERE TO_dATE(T.PSA003FT, 'RRRRMMDD') = P_FEC_PROCESO;
         END;
         --commit;
      END IF;



      PR_PRE_PRO_REGISTROS('PSA003',SYSDATE,V_REPROCESO);
      PR_LOG_PSAML('PR_GEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTO NORMALES');
     --MOVIMIENTOS NORMALES
     BEGIN
      insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
         SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,TRIM(movi.nro_bin) psa003bi --csbin
               ,TRIM(movi.nro_canal) psa003ca --cscanaltrx
               ,TRIM(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,TRIM(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,TRIM(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,TRIM(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,TRIM(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               ,modcta.modulo psa003ct
               ,TRIM(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,TRIM(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,TRIM(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,TRIM(MOVI.MONTO) psa003dl --cmmonto dolares
               ,TRIM(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,TRIM(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,TRIM(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,TRIM(MOVI.CAJERO) psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,TRIM(movi.cotizacion_origen) psa003md -- moneda origen
               ,TRIM(movi.moneda_local) psa003ml --cmmonto moneda local
               ,TRIM(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,TRIM(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               ,MOVI.NRO_CTA_BANTOTAL psa003nc --csnumerocuenta
               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES') psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,TRIM(movi.referencia) psa003rf --referencia
               ,/*PK*/ (999999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,TRIM(pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta)) psa003so --sub operación
               ,MOVI.NRO_SUB_CTA_BANTOTAL psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,TRIM(movi.tip_per_documento) psa003td --tipo doc
               ,TRIM(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,TRIM(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion

           FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       , pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,
                        -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
                        MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       /*,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            nvl((select tdd.nro_tarjeta
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1),P.NRO_DOCUMENTO)
                           when mov.cod_usuario not like 'ATM%' then
                            p.nro_documento
                           else
                            null
                        end) nro_tarjeta_documento*/
                       , p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                       , MCL.NRO_CTA_BANTOTAL
                       , MCL.NRO_SUB_CTA_BANTOTAL
                   FROM GE_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       ,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                       ,MI_CTA_CLIENTES MCL
                  WHERE mov.nro_cuenta = c.nro_cuenta
                    and c.cod_persona = p.cod_persona
                    AND C.RELACION = 'P'
                    --
                    AND MOV.NRO_CUENTA = MCL.NRO_CTA_ITGF
                    AND P.COD_PERSONA = MCL.COD_PERSONA
                    --
                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)
                       /*AND (ATR.cod_modulo in (3, 4, 6) OR
                       (ATR.cod_modulo = 9 AND ATR.cod_mod_padre in (3, 4, 6)))*/

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO
                       --and fecha = to_date('19/02/2021', 'DD/MM/YYYY')
                       --AND TRUNC(FECHA) = PAI_PSA.FU_OBT_FEC_PROCESO
                       --para el control de transferencias HBank a terceros

                       --COMENTADO PARA PSAML
                    /*AND ((ATR.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I') AND
                        MOV.COD_USUARIO = 'HBANK' AND (INSTR(MOV.CONCEPTO, 'Transf. a', 1, 1) > 0 AND
                        INSTR(MOV.CONCEPTO, ' desde ', 1, 1) > 0 OR
                        (MOV.CONCEPTO = 'Pago de Sueldo ') OR
                        (MOV.CONCEPTO = 'Pago de Aguinaldo '))) OR
                        (ATR.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I') OR
                        MOV.COD_USUARIO != 'HBANK'))*/
                      --COMENTADO PARA PSAML

                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI, (select distinct ctx.nro_cta_bantotal,
                                          ctx.referencia3 modulo
                                     from mi_cta_clientes ctx)modcta
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA)
            
            and movi.NRO_CTA_BANTOTAL = modcta.nro_cta_bantotal
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                )

             --Solamente los Productos PRO-21-GS, PRO-21-ME, PRO-20-GS,
             --PRO-20-ME, PRO-22-GS y PRO-22-ME. Consideramos como creditos y debitos,
             --por tanto, los demás productos solo consideramos como Creditos.
                and  ((modcta.modulo not in (20,21,22)
                      and decode(MOVI.TIPO, 'D', 1, 2) = 2)--mov crédito
                      or (modcta.modulo in (20,21,22))
                     );
      END;

      PR_LOG_PSAML('PR_GEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTO EFECTIVO X EFECTIVO EN CAJA');
     --MOVIMEINTO EFECTIVO X EFECTIVO EN CAJA (POR EJ COMPRA DE DIVISAS)
     BEGIN
        insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
          SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,trim(movi.nro_bin) psa003bi --csbin
               ,trim(movi.nro_canal) psa003ca --cscanaltrx
               ,trim(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,trim(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,trim(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,trim(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,trim(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               --,modcta.modulo psa003ct
               ,20 psa003ct --(cuenta corriente )valor por defecto para operaciones de efectivo en caja
               ,trim(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,trim(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,trim(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,trim(MOVI.MONTO) psa003dl --cmmonto dolares
               ,trim(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,trim(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,trim(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,MOVI.CAJERO psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,trim(movi.cotizacion_origen) psa003md -- moneda origen
               ,trim(movi.moneda_local) psa003ml --cmmonto moneda local
               ,trim(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,trim(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               /*,(SELECT MCL.NRO_CTA_BANTOTAL
                 FROM MI_CTA_CLIENTES MCL
                 WHERE MCL.COD_PERSONA = MOVI.COD_PERSONA
                 AND MCL.PRINCIPAL = 'P' AND ROWNUM = 1)psa003nc --csnumerocuenta*/

               ,nvl((SELECT MCL.NRO_CTA_BANTOTAL
                     FROM MI_CTA_CLIENTES MCL
                    WHERE MCL.COD_PERSONA = MOVI.cod_persona
                      AND MCL.PRINCIPAL = 'P'
                      AND ROWNUM = 1),
                   (SELECT MCL.NRO_CTA_BANTOTAL
                      FROM MI_CTA_CLIENTES MCL
                     WHERE MCL.COD_PERSONA = MOVI.cod_persona
                       AND MCL.PRINCIPAL = 'N'
                       AND ROWNUM = 1))psa003nc --csnumerocuenta
               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,trim(PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES')) psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,trim(movi.referencia) psa003rf --referencia
               ,/*PK*/ (998999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta) psa003so --sub operación
               ,1 psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,trim(movi.tip_per_documento) psa003td --tipo doc
               ,trim(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,trim(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion
               --,TO_DATE('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') FPSA003FI
               --,movi.fec_valor FPSA003FT
               --,movi.fecha_hora FPSA003HT
               FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       ,pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       ,p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                   FROM GE_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       --,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                  WHERE

                     mov.COD_PERSONA  = p.cod_persona
                    AND MOV.COD_PERSONA IS NOT NULL
                    AND MOV.NRO_CUENTA IS NULL

                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO



                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.COD_PERSONA = MOVI.COD_PERSONA)
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                );
     END;

     PR_LOG_PSAML('PR_GEN_ARC_MOVIMIENTOS','PSA003', 'MOVIMIENTO PRESTAMOS');
     --movimientos préstamos
     BEGIN
      insert into psa003
         (PSA003AF,
          PSA003AU,
          PSA003BI,
          PSA003CA,
          PSA003CB,
          PSA003CD,
          PSA003CI,
          PSA003CL,
          PSA003CO,
          PSA003CR,
          PSA003CT,
          PSA003DA,
          PSA003DB,
          PSA003DD,
          PSA003DH,
          PSA003DL,
          PSA003DO,
          PSA003DR,
          PSA003DT,
          PSA003EB,
          PSA003EO,
          PSA003FC,
          PSA003FI,
          PSA003FT,
          PSA003FU,
          PSA003HT,
          PSA003ID,
          PSA003MC,
          PSA003MD,
          PSA003ML,
          PSA003MO,
          PSA003MP,
          PSA003MU,
          PSA003NC,
          PSA003OP,
          PSA003OR,
          PSA003OS,
          PSA003PA,
          PSA003PD,
          PSA003PR,
          PSA003RF,
          PSA003RL,
          PSA003RV,
          PSA003SO,
          PSA003ST,
          PSA003SU,
          PSA003TA,
          PSA003TD,
          PSA003TP,
          PSA003TR,
          PSA003TT)
         SELECT null psa003af --codigo de afiliado
               ,null psa003au --csautorizacion
               ,TRIM(movi.nro_bin) psa003bi --csbin
               ,TRIM(movi.nro_canal) psa003ca --cscanaltrx
               ,TRIM(lpad(movi.beneficiario, 25)) psa003cb --cscuentabeneficiario
               ,TRIM(movi.cot_usd) /*v_cotizacion_usd */ psa003cd --citipocambio dólar TODO
                --,PAI_PSA.FU_OBT_DES_CIU_BTL_PSA(movi.cod_ciu_oficina, movi.cod_pai_oficina, 'BA_CIUDADES') psa003ci --ciudad
               ,TRIM(movi.nom_ciudad) psa003ci --ciudad
               --,0 psa003cl --citipocambio local
               ,TRIM(movi.cot_eur) psa003cl --citipocambio local (tipo de cambio euro)
               ,TRIM(lpad(movi.originador, 25)) psa003co --cscuentaordenante
               ,null psa003cr --cscodigorespuesta
               --,TRIM(decode(movi.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5)) psa003ct --cstipocuenta
               ,modcta.modulo psa003ct
               ,TRIM(lpad(movi.afiliado, 40)) psa003da --descripcion afiliado
               ,TRIM(lpad(movi.det_transaccion, 25)) psa003db --cscedulabeneficiario
               ,'B' psa003dd --BANCO REMITENTE (NUEVO)
               ,TRIM(decode(MOVI.TIPO, 'D', 1, 2)) psa003dh --cstipomovimiento
               ,TRIM(MOVI.MONTO) psa003dl --cmmonto dolares
               ,TRIM(movi.nro_documento) psa003do --csNumeroTarjeta (Cédula)
               ,null psa003dr --cscedulaordenante
               ,null psa003dt --tipo doc del depositante
               ,TRIM(lpad(movi.banco_beneficiario, 65)) psa003eb --csentidadbeneficiario
               ,TRIM(lpad(movi.banco_emisor, 65)) psa003eo --csentidadordenante
               ,null psa003fc --csfuncionario confirma
               ,TO_TIMESTAMP('1753-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS') psa003fi --cdfechahoraingreso
               ,/*PK*/ TO_CHAR(movi.fec_valor,'YYYYMMDD') psa003ft --cdfechahoratransaccion
               ,TRIM(MOVI.CAJERO) psa003fu --csfuncionario ingreso
               ,TO_CHAR(movi.fecha_hora,'HH24:MI:SS') psa003ht --hora de la transaccion
               ,null psa003id --ciidtransaccionpk
               ,null psa003mc --cscodigomcc tipo de comercio
               ,TRIM(movi.cotizacion_origen) psa003md -- moneda origen
               ,TRIM(movi.moneda_local) psa003ml --cmmonto moneda local
               ,TRIM(movi.moneda_origen) psa003mo --cmmonto moneda origen
               ,TRIM(TO_NUMBER(PAI_PSA.FU_OBT_COD_BTL_PSA(MOVI.COD_GRU_TRANSACCION, 'GE_GRU_TRA_ASSIST'))) psa003mp --medio de pago
               --,/*PK*/ movi.cod_modulo psa003mu --modulo contable /*PK*/
               ,/*PK*/ nvl(movi.cod_mod_bantotal,movi.cod_modulo) psa003mu --modulo contable /*PK*/
               --,7||lpad(movi.COD_PERSONA,8,0) psa003nc --csnumerocuenta
               ,MOVI.NRO_CTA_BANTOTAL psa003nc --csnumerocuenta
               --,9||lpad(movi.cod_persona,6,0)||substr(movi.Nro_Cuenta,-2) psa003nc
               ,0 psa003op --operación
               ,/*PK*/ 0 psa003or --ordinal
               ,/*PK*/ 0 psa003os --sub-ordinal
               ,PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_pai_doc, 'BA_PAISES') psa003pa --pais doc
               ,0 psa003pd --pais del depositante
               ,null psa003pr --ciidprocesofk
               ,TRIM(movi.referencia) psa003rf --referencia
               ,/*PK*/ (997999999 - rownum) psa003rl --relacion contable
               ,'N' psa003rv --csreversada
               --,TRIM(pai_psa.FU_OBT_NRO_SUB_OPERACION(movi.COD_PERSONA, movi.nro_cuenta)) psa003so --sub operación
               ,MOVI.NRO_SUB_CTA_BANTOTAL psa003so --sub operación
               ,null psa003st --cmsaldotc
               ,/*PK*/ PAI_PSA.FU_OBT_COD_BTL_PSA(movi.cod_oficina, 'BA_OFICINAS') psa003su  --Sucursal contable /*PK*/
               --,/*PK*/ LPAD(movi.cod_tra_mod_mad_padre, 9) psa003ta --transaccion contable /*PK*/
               ,/*PK*/ LPAD(nvl(movi.cod_tra_bantotal,movi.cod_tra_mod_mad_padre), 9) psa003ta --transaccion contable /*PK*/
               ,TRIM(movi.tip_per_documento) psa003td --tipo doc
               ,TRIM(movi.tip_persona) psa003tp --ciidtipocliente
               ,null psa003tr --csclasetransentrecnts
               ,TRIM(movi.COD_AST_TRANSACCION) psa003tt --cstipotransaccion

           FROM (SELECT ATR.Cod_cum_Transaccion COD_AST_TRANSACCION
                       ,
                        --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_PSA.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
                        round(DECODE(MOV.COD_MONEDA, 'USD', MOV.MONTO, 'EUR',
                                     ((MOV.MONTO * v_cotizacion_eur) / v_cotizacion_usd), 'GS',
                                     MOV.MONTO / v_cotizacion_usd, 0), v_redondeo) MONTO

                       /*,decode(mov.cod_moneda, 'GS', 1, 'EUR', v_cotizacion_eur, 'USD',
                               v_cotizacion_usd) cotizacion_origen -- moneda origen*/
                       , pai_psa.FU_OBT_COD_BTL_PSA(mov.cod_moneda,'BA_MONEDAS')cotizacion_origen -- moneda origen
                       ,decode(mov.cod_moneda, 'GS', mov.monto, 'EUR', mov.monto * v_cotizacion_eur,
                               'USD', mov.monto * v_cotizacion_usd) moneda_local --cmmonto moneda local
                       ,mov.monto moneda_origen --cmmonto moneda origen

                       ,/*TO_CHAR(MOV.FECHA, 'MM/DD/YYYY')*/ MOV.FECHA FEC_VALOR
                       ,MOV.NRO_CUENTA NRO_CUENTA
                       ,
                        --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
                        TR.DESCRIPCION CONCEPTO
                       ,MOV.MONTO MONTO_ORIGINAL
                       ,MOV.COD_MONEDA COD_MONEDA
                       ,MOV.COD_MODALIDAD COD_MODALIDAD
                       ,MOV.HORA HORA
                       ,ATR.COD_GRU_TRANSACCION
                       ,ATR.TIPO TIPO
                       , --DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
                        NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 2,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                     'C', TR.TIPO), MOV.COD_TRA_PADRE,
                                                             MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') ORIGINADOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 3,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 4,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_INTERMEDIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 5,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BANCO_BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 6,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BENEFICIARIO
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 7,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_EMISOR
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 8,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') COD_PAI_BANCO_BENEFIARIO
                       ,replace(replace(NVL(MOV.CONCEPTO, TR.DESCRIPCION), chr(13) || chr(10), ' '),
                                chr(10), ' ') DET_TRANSACCION
                       ,TO_CHAR(MOV.FECHA, 'MM/DD/YYYY') FEC_VALOR2
                       ,NVL(PAI_PSA.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO, MOV.NRO_CUENTA, 9,
                                                             MOV.HORA, MOV.COD_USUARIO, MOV.FECHA,
                                                             DECODE(MOV.COD_TRANSACCION, 515, 'C',
                                                                     560, 'C', TR.TIPO),
                                                             MOV.COD_TRA_PADRE, MOV.COD_TRANSACCION,
                                                             ATR.COD_GRU_TRANSACCION, MOV.COD_BANCO,
                                                             MOV.MONTO), ' ') BAN_INTERMEDIARIO_CORTO
                       ,MOV.COD_OFICINA COD_OFICINA
                       ,
                        -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
                        MOV.COD_USUARIO CAJERO
                       ,MOV.HORA HORA2
                       ,mov.cod_modulo
                       ,pai_psa.FU_OBT_NRO_CANAL(mov.cod_tra_padre, mov.cod_usuario,
                                                 mov.nro_documento, mov.nro_documento2,
                                                 mov.nro_documento3, mov.nro_cuenta,
                                                 mov.fec_insercion) nro_canal

                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            (select tdd.nro_bin
                               from ah_tar_debitos tdd
                              where tdd.nro_cuenta = mov.nro_cuenta
                                and rownum = 1)
                           else
                            null
                        end) nro_bin
                       , p.nro_documento
                       ,(case
                           when mov.cod_modulo in (3, 4) and mov.cod_usuario like 'ATM%' then

                            mov.concepto
                        end) afiliado
                       ,p.tipo tip_persona
                       ,P.COD_PERSONA
                       ,PAI_PSA.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') tip_per_documento
                       ,mov.cod_rubro
                       ,mov.cod_Tra_padre||mov.cod_mod_padre||mov.cod_mad_padre cod_tra_mod_mad_padre
                       ,mov.nro_documento3 referencia
                       ,ofi.cod_ciudad cod_ciu_oficina
                       ,ofi.cod_pais cod_pai_oficina
                       ,ci.descripcion nom_ciudad
                       ,nvl(p.cod_pai_documento,p.cod_pais) cod_pai_doc
                       ,v_cotizacion_eur cot_eur --
                       ,v_cotizacion_usd cot_usd --
                       ,to_Date(to_char(mov.fecha, 'dd/mm/yyyy') || ' ' || mov.hora,
                                'dd/mm/yyyy hh24:mi:ss') fecha_hora
                       , atr.cod_tra_bantotal
                       , atr.cod_mod_bantotal
                       ,substr(MOV.concepto, -10) NRO_CUENTA_PR
                        , MCL.NRO_CTA_BANTOTAL
                       , MCL.NRO_SUB_CTA_BANTOTAL
                   FROM GE_MOVIMIENTOS       MOV
                       ,ge_cum_transacciones ATR
                       ,GE_TRANSACCIONES     TR
                       ,ba_personas          p
                       ,ge_cta_clientes      c
                       ,ba_oficinas          ofi
                       ,ba_ciudades          ci
                       ,MI_CTA_CLIENTES MCL
                  WHERE --mov.nro_cuenta = c.nro_cuenta


                    substr(MOV.concepto, -10) = C.NRO_CUENTA
                    and c.cod_persona = p.cod_persona
                    AND C.RELACION = 'P'

                    AND MOV.NRO_CUENTA IS NULL
                    AND MOV.COD_PERSONA IS NULL
                    AND MOV.COD_MOD_PADRE = 6 --préstamos

                     --
                    AND C.NRO_CUENTA = MCL.NRO_CTA_ITGF
                    AND P.COD_PERSONA = MCL.COD_PERSONA
                    --

                    and mov.cod_oficina = ofi.cod_oficina
                    and ofi.cod_ciudad = ci.cod_ciudad
                    and ofi.cod_pais = ci.cod_pais
                    and MOV.COD_MODULO = ATR.COD_MODULO
                    AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
                    AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
                    AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
                    AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
                    AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE
                    AND ATR.COD_MODULO = TR.COD_MODULO
                    AND ATR.COD_MODALIDAD = TR.COD_MODALIDAD
                    AND ATR.COD_TRANSACCION = TR.COD_TRANSACCION
                       --AH,CC y PR
                    AND (ATR.cod_transaccion > 0 OR mov.cod_rubro IS NOT NULL)
                       /*AND (ATR.cod_modulo in (3, 4, 6) OR
                       (ATR.cod_modulo = 9 AND ATR.cod_mod_padre in (3, 4, 6)))*/

                    AND MOV.REVERSADO = 'N'

                    AND FECHA = P_FEC_PROCESO
                       --and fecha = to_date('19/02/2021', 'DD/MM/YYYY')
                       --AND TRUNC(FECHA) = PAI_PSA.FU_OBT_FEC_PROCESO
                       --para el control de transferencias HBank a terceros

                       --COMENTADO PARA PSAML

                      --COMENTADO PARA PSAML

                       --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                    AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND
                        ATR.Cod_cum_Transaccion IN (252, 210) --(cuando se recibe cheques)
                        AND
                        PAI_PSA.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO, MOV.COD_USUARIO,
                                                           MOV.FECHA, MOV.NRO_CUENTA,
                                                           DECODE(MOV.COD_TRANSACCION, 515, 'C', 560,
                                                                   'C', TR.TIPO), MOV.MONTO) = 'N' --se excluye los cheq devueltos
                        ) OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I' OR
                        ATR.Cod_cum_Transaccion NOT IN (252, 210)))

                 ) MOVI, (select distinct ctx.nro_cta_bantotal,
                                          ctx.referencia3 modulo
                                     from mi_cta_clientes ctx)modcta
          WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.ORIGINADOR --<control>
                ) OR
                (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E', 'TRNINT-I', 'TRASFN-E', 'TRASFN-I')))

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E', 'TRASFN-I') AND
                MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR --<control>
                AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO --<control>
                ) OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E', 'TRASFN-I')))

            AND EXISTS (SELECT 1 FROM GE_CTA_IMP_PSAML X WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA)
            
            and movi.NRO_CTA_BANTOTAL = modcta.nro_cta_bantotal
            --Los canales "CAN-139, CAN-140 y CAN-66.
            --Solo consideramos como debitos, no asi como creditos.
            and ((movi.nro_canal in (139,140,66)
                  and decode(MOVI.TIPO, 'D', 1, 2) = 1)--mov debito (ajustado)
                 or (movi.nro_canal not in (139,140,66))
                )

             --Solamente los Productos PRO-21-GS, PRO-21-ME, PRO-20-GS,
             --PRO-20-ME, PRO-22-GS y PRO-22-ME. Consideramos como creditos y debitos,
             --por tanto, los demás productos solo consideramos como Creditos.
                and  ((modcta.modulo not in (20,21,22)
                      and decode(MOVI.TIPO, 'D', 1, 2) = 2)--mov crédito
                      or (modcta.modulo in (20,21,22))
                     );

      END;

   END;



 PROCEDURE PR_GEN_ARC_MOV_MASIVOS(P_FEC_DESDE IN DATE, P_FEC_HASTA IN DATE)IS
   cursor c_movs is
     Select DISTINCT T.FECHA
     from GV_MOVIMIENTOS T
     WHERE T.FECHA >= P_FEC_DESDE
     AND T.FECHA <= P_FEC_HASTA
     /*and exists (select 's'
                 from cum_per_verificaciones_ss a
                 where a.nro_cuenta = t.nro_cuenta)*/
     order by 1;
   BEGIN

       --control de tablas de AS400
       PR_VAL_TAB_BANTOTAL; --VALIDA QUE LOS DATOS DE TABLAS DE BANTOTAL SE HAYAN MIGRADO (FSD001, ETC)
       PR_LOG_PSAML('PR_VAL_TAB_BANTOTAL');

       PR_ACT_CLI_COMUNES; --ACTUALIZA LOS CLIENTES COMUNES
       PR_LOG_PSAML('PR_ACT_CLI_COMUNES');
       FOR C IN C_MOVS LOOP
           --logtest('PR_GEN_ARC_MOV_MASIVOS - '||C.FECHA,'INICIO');

           --logtest('PR_INS_CTA_PSAML - '||C.FECHA,'INICIO');
           PR_INS_CTA_PSAML(V_FEC_PROCESO);
           PR_LOG_PSAML('PR_INS_CTA_PSAML',C.FECHA,'FIN');

           --logtest('PR_MIG_CTA_CLIENTES - '||C.FECHA,'INICIO');
           PR_MIG_CTA_CLIENTES;
           PR_LOG_PSAML('PR_MIG_CTA_CLIENTES',C.FECHA,'FIN');

           --logtest('PR_GEN_ARC_MOVIMIENTOS - '||C.FECHA,'INICIO');
           PR_REGEN_ARC_MOVIMIENTOS(C.FECHA);
           PR_LOG_PSAML('PR_GEN_ARC_MOVIMIENTOS',C.FECHA,'FIN');

           --logtest('PR_GEN_ARC_CUENTAS - '||C.FECHA,'INICIO');
           PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);
           PR_LOG_PSAML('PR_GEN_ARC_CUENTAS ',C.FECHA,'FIN');

           --logtest('PR_GEN_ARC_MOV_MASIVOS - '||C.FECHA,'FIN');
           --commit;

       END LOOP;

       --lleva el último día generado al histórico
       PR_PRE_PRO_REGISTROS('PSA003',SYSDATE,V_REPROCESO);
       COMMIT;
       PR_LOG_PSAML('PR_PRE_PRO_REGISTROS ',SYSDATE,V_REPROCESO);
   END;



 PROCEDURE PR_GEN_DAT_PSAML_TEST_MASIVO(P_FEC_DESDE IN DATE, P_FEC_HASTA IN DATE)IS
   cursor c_movs is
     Select DISTINCT T.FECHA
     from GV_MOVIMIENTOS T
     WHERE T.FECHA >= P_FEC_DESDE
     AND T.FECHA <= P_FEC_HASTA
     /*and exists (select 's'
                 from cum_per_verificaciones_ss a
                 where a.nro_cuenta = t.nro_cuenta)*/
     order by 1;
   BEGIN
       FOR C IN C_MOVS LOOP
           --logtest('PROCESO MASIVO PSAML TEST - '||C.FECHA,'INICIO');
           PR_GEN_DAT_PSAML_TEST(C.FECHA);
           PR_LOG_PSAML('PROCESO MASIVO PSAML TEST',C.FECHA,'FIN');
           commit;

       END LOOP;
        --lleva el último día generado al histórico
       PR_PRE_PRO_REGISTROS('PSA003',SYSDATE,V_REPROCESO);
       PR_LOG_PSAML('PSA003',SYSDATE,V_REPROCESO);
       COMMIT;
   END;






   --- PROCEDIMIENTO PRINCIPAL QUE GENERA TODOS LOS ARCHIVOS ---
   PROCEDURE PR_GEN_DAT_PSAML IS
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      -- Cargo la fecha de proceso del calendario
      V_REPROCESO := 'N';
      --
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      --
      V_FEC_PROCESO := PAI_PSA.FU_OBT_FEC_PROCESO;
      --tool_pro_log_proceso(SYSDATE, V_FEC_PROCESO);
      -- Verifico si todavia no se procesó, si ya se proceso en la fecha utilizar el reproceso.
      PR_LOG_PSAML('PR_GEN_DAT_PSAML','V_FEC_PROCESO', to_char(V_FEC_PROCESO));
      PR_LOG_PSAML('PR_REGEN_DAT_PSAML','FECHA DE PROCESO', to_char(sysdate));
      IF NOT PAI_PSA.FU_VER_FEC_PROCESO(V_FEC_PROCESO) THEN

         --control de tablas de AS400
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_VAL_TAB_BANTOTAL', 'INICIO');
         PR_VAL_TAB_BANTOTAL; --VALIDA QUE LOS DATOS DE TABLAS DE BANTOTAL SE HAYAN MIGRADO (FSD001, ETC)
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_ACT_TAB_BANTOTAL', 'INICIO');
         PR_ACT_TAB_BANTOTAL;--update masivo tablas bantotal
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_ACT_CLI_COMUNES', 'INICIO');
         PR_ACT_CLI_COMUNES; --ACTUALIZA LOS CLIENTES COMUNES
         -- Cargo los clientes de la fecha
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_INS_CTA_PSAML', 'INICIO');
         PR_INS_CTA_PSAML(V_FEC_PROCESO);
         --genera las sub cuentas para el formato bantotal
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_MIG_CTA_CLIENTES', 'INICIO');
         PR_MIG_CTA_CLIENTES;
         --re actualiza los oficiales del cliente en cada proceso
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_PRO_OFICIAL_CLIENTE', 'INICIO');
         PR_PRO_OFICIAL_CLIENTE(V_FEC_PROCESO);


         --PSAML
         --PR_GEN_ARC_CATALOGOS;   -- PSA001 CATALOGOS
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_LIS_CLIENTE', 'INICIO');
         PR_GEN_ARC_LIS_CLIENTE(V_FEC_PROCESO); -- PSA002 LISTA DE CLIENTE (TODO)
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_MOVIMIENTOS', 'INICIO');
         PR_GEN_ARC_MOVIMIENTOS(V_FEC_PROCESO); -- PSA003 MOVIMIENTOS
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_RELACIONES', 'INICIO');
         PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);  -- PSA004 RELACIONES
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_PERFILES', 'INICIO');
         PR_GEN_ARC_PERFILES(V_FEC_PROCESO);    -- PSA005 DECLARACIONES
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_CUENTAS', 'INICIO');
         PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);     -- PSA006 PRODUCTOS
         ---
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_GEN_ARC_CLIENTES', 'INICIO');
         PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);    -- PSA007 CLIENTES
         COMMIT;
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_ACT_CTA_CLIENTES', 'INICIO');
         PR_ACT_CTA_CLIENTES;                   --actualización de cuentas por act en personas
         COMMIT;
         PR_ENV_MAIL(v_fec_proceso,'PSAML');    -- envío de mail notificación
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','PR_TRU_TAB_BANTOTAL', 'INICIO');
         PR_TRU_TAB_BANTOTAL;                   --trunca las tablas de bantotal

         commit;
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','COMMIT', 'FIN');
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Ya se proceso la fecha ' || V_FEC_PROCESO);
      END IF;
      --
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al generar datos interfaces PSAML - ' || sqlerrm);
   END;


   PROCEDURE PR_GEN_DAT_PSAML_TEST(P_FEC_PROCESO IN DATE) IS
   BEGIN
      PR_LOG_PSAML('inicio proceso PSAML TEST');
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      -- Cargo la fecha de proceso del calendario
      V_REPROCESO := 'N';
      --
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      --
      V_FEC_PROCESO := P_FEC_PROCESO;--PAI_PSA.FU_OBT_FEC_PROCESO;

      -- Verifico si todavia no se procesó, si ya se proceso en la fecha utilizar el reproceso.
      IF NOT PAI_PSA.FU_VER_FEC_PROCESO(V_FEC_PROCESO) THEN
         --logtest('PR_INS_CTA_PSAML'||' - '||V_FEC_PROCESO,'INICIO');
         -- Cargo los clientes de la fecha
         PR_INS_CTA_PSAML(V_FEC_PROCESO);
         PR_LOG_PSAML('PR_INS_CTA_PSAML',V_FEC_PROCESO,'FIN');
         --logtest('PR_MIG_CTA_CLIENTES'||' - '||V_FEC_PROCESO,'INICIO');
         --genera las sub cuentas para el formato bantotal
         PR_MIG_CTA_CLIENTES;
         PR_LOG_PSAML('PR_MIG_CTA_CLIENTES',V_FEC_PROCESO,'FIN');
         --logtest('PR_PRO_OFICIAL_CLIENTE'||' - '||V_FEC_PROCESO,'INICIO');
         --re actualiza los oficiales del cliente en cada proceso
         PR_PRO_OFICIAL_CLIENTE(V_FEC_PROCESO);
         PR_LOG_PSAML('PR_PRO_OFICIAL_CLIENTE',V_FEC_PROCESO,'FIN');


         --PSAML
         --PR_GEN_ARC_CATALOGOS;   -- PSA001 CATALOGOS
         --logtest('PR_GEN_ARC_LIS_CLIENTE'||' - '||V_FEC_PROCESO,'INICIO');
         PR_GEN_ARC_LIS_CLIENTE(V_FEC_PROCESO); -- PSA002 LISTA DE CLIENTE (TODO)
         PR_LOG_PSAML('PR_GEN_ARC_LIS_CLIENTE',V_FEC_PROCESO,'FIN');
         --logtest('PR_GEN_ARC_MOVIMIENTOS'||' - '||V_FEC_PROCESO,'INICIO');
         PR_REGEN_ARC_MOVIMIENTOS(V_FEC_PROCESO); -- PSA003 MOVIMIENTOS
         PR_LOG_PSAML('PR_GEN_ARC_MOVIMIENTOS',V_FEC_PROCESO,'FIN');
         --logtest('PR_GEN_ARC_RELACIONES'||' - '||V_FEC_PROCESO,'INICIO');
         PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);  -- PSA004 RELACIONES
         PR_LOG_PSAML('PR_GEN_ARC_RELACIONES',V_FEC_PROCESO,'FIN');
         --logtest('PR_GEN_ARC_PERFILES'||' - '||V_FEC_PROCESO,'INICIO');
         PR_GEN_ARC_PERFILES(V_FEC_PROCESO);    -- PSA005 DECLARACIONES
         PR_LOG_PSAML('PR_GEN_ARC_PERFILES',V_FEC_PROCESO,'FIN');
         --logtest('PR_GEN_ARC_CUENTAS'||' - '||V_FEC_PROCESO,'INICIO');
         PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);     -- PSA006 PRODUCTOS
         PR_LOG_PSAML('PR_GEN_ARC_CUENTAS',V_FEC_PROCESO,'FIN');
         --logtest('PR_GEN_ARC_CLIENTES'||' - '||V_FEC_PROCESO,'INICIO');
         PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);    -- PSA007 CLIENTES
         PR_LOG_PSAML('PR_GEN_ARC_CLIENTES',V_FEC_PROCESO,'FIN');
         --logtest('PR_ENV_MAIL'||' - '||V_FEC_PROCESO,'INICIO');
         PR_ENV_MAIL(v_fec_proceso,'PSAML');            -- envío de mail notificación
         PR_LOG_PSAML('PR_ENV_MAIL',V_FEC_PROCESO,'FIN');
         commit;
      ELSE
         RAISE_APPLICATION_ERROR(-20001, 'Ya se proceso la fecha ' || V_FEC_PROCESO);
      END IF;
      --
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al generar datos interfaces PSAML - ' || sqlerrm);
   END;

   --- PROCEDIMIENTO PRINCIPAL QUE GENERA TODOS LOS ARCHIVOS ---


   -- Regeneración de archivos a una fecha dada que ya se haya procesado.
   PROCEDURE PR_REGEN_DAT_PSAML IS
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      --
      V_REPROCESO := 'S';
      -- Si es automatico viene nulo, si es por demanda viene con la fecha que indica el usuario.
      V_FEC_PROCESO := PAI_PSA.FU_OBT_FEC_PROCESO;
      --
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      --
      PR_LOG_PSAML('PR_REGEN_DAT_PSAML','V_FEC_PROCESO', to_char(V_FEC_PROCESO));
      PR_LOG_PSAML('PR_REGEN_DAT_PSAML','FECHA DE REPROCESO', to_char(sysdate));
      IF V_FEC_PROCESO IS NOT NULL THEN
         --control de tablas de AS400
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_VAL_TAB_BANTOTAL', 'INICIO');
         PR_VAL_TAB_BANTOTAL; --VALIDA QUE LOS DATOS DE TABLAS DE BANTOTAL SE HAYAN MIGRADO (FSD001, ETC)
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_ACT_TAB_BANTOTAL', 'INICIO');
	      PR_ACT_TAB_BANTOTAL;--update masivo tablas bantotal	
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_ACT_CLI_COMUNES', 'INICIO');
         PR_ACT_CLI_COMUNES; --ACTUALIZA LOS CLIENTES COMUNES

         -- Cargo los clientes de la fecha
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_INS_CTA_PSAML', 'INICIO');
         PR_INS_CTA_PSAML(V_FEC_PROCESO);
         --genera las sub cuentas para el formato bantotal
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_MIG_CTA_CLIENTES', 'INICIO');
         PR_MIG_CTA_CLIENTES;
         --re actualiza los oficiales del cliente en cada proceso
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_PRO_OFICIAL_CLIENTE', 'INICIO');
         PR_PRO_OFICIAL_CLIENTE(V_FEC_PROCESO);


         --PSAML
         --PR_GEN_ARC_CATALOGOS;   -- PSA001 CATALOGOS
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_GEN_ARC_LIS_CLIENTE', 'INICIO');
         PR_GEN_ARC_LIS_CLIENTE(V_FEC_PROCESO); -- PSA002 LISTA DE CLIENTE (TODO)
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_REGEN_ARC_MOVIMIENTOS', 'INICIO');
         PR_REGEN_ARC_MOVIMIENTOS(V_FEC_PROCESO); -- PSA003 MOVIMIENTOS
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_GEN_ARC_RELACIONES', 'INICIO');
         PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);  -- PSA004 RELACIONES
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_GEN_ARC_PERFILES', 'INICIO');
         PR_GEN_ARC_PERFILES(V_FEC_PROCESO);    -- PSA005 DECLARACIONES
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_GEN_ARC_CUENTAS', 'INICIO');
         PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);     -- PSA006 PRODUCTOS
         ---
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_GEN_ARC_CLIENTES', 'INICIO');
         PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);    -- PSA007 CLIENTES
         COMMIT;
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_ACT_CTA_CLIENTES', 'INICIO');
         PR_ACT_CTA_CLIENTES;                   --actualización de cuentas por act en personas
         COMMIT;
         PR_ENV_MAIL(v_fec_proceso,'PSAML');    -- envío de mail notificación
         PR_LOG_PSAML('PR_REGEN_DAT_PSAML','PR_TRU_TAB_BANTOTAL', 'INICIO');
         PR_TRU_TAB_BANTOTAL; --trunca las tablas de bantotal
         commit;
         PR_LOG_PSAML('PR_GEN_DAT_PSAML','COMMIT', 'FIN');
      ELSE
         RAISE_APPLICATION_ERROR(-20000, 'No está configurado la fecha de proceso en el parámetro ');
      END IF;
      --
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al ejecutar Creacion de Archivos para ASSIST' || sqlerrm);
   END;

   PROCEDURE PR_GEN_DAT_PSAML_DEV(P_FEC_DESDE IN DATE, P_FEC_HASTA IN DATE) IS
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      -- Cargo la fecha de proceso del calendario
      V_REPROCESO := 'N';
      --
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      --
      V_FEC_PROCESO := P_FEC_HASTA; --PAI_PSA.FU_OBT_FEC_PROCESO;
      --tool_pro_log_proceso(SYSDATE, P_FEC_HASTA);
      -- Verifico si todavia no se procesó, si ya se proceso en la fecha utilizar el reproceso.
      IF NOT PAI_PSA.FU_VER_FEC_PROCESO(V_FEC_PROCESO) THEN
         --tool_pro_log_proceso(SYSDATE, 'INICIO PROCESO', 'PSAML');

         --tool_pro_log_proceso(SYSDATE, 'INICIO PR_INS_CTA_PSAML', 'PSAML');
         -- Cargo los clientes de la fecha
         PR_INS_CTA_PSAML_DEV(P_FEC_DESDE, P_FEC_HASTA);
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_INS_CTA_PSAML', 'PSAML');
         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_MIG_CTA_CLIENTES','PSAML');
         PR_MIG_CTA_CLIENTES_dev(p_fec_Desde, p_fec_hasta);
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_MIG_CTA_CLIENTES', 'PSAML');

         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_PRO_SEG_CLIENTE','PSAML');

         --tool_pro_log_proceso(SYSDATE,'INICIO PR_PRO_OFICIAL_CLIENTE','PSAML');
         PR_PRO_OFICIAL_CLIENTE(V_FEC_PROCESO);
         --tool_pro_log_proceso(SYSDATE,'FIN PR_PRO_OFICIAL_CLIENTE','PSAML');

         commit;

         -------- LAYOUTS CATALOGO ---------------------------------------

         --PSAML
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_CATALOGOS','PSAML');
         PR_GEN_ARC_CATALOGOS; -- PSA001 CATALOGOS
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_GEN_ARC_CATALOGOS', 'PSAML');
         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_LIS_CLIENTE','PSAML');
         PR_GEN_ARC_LIS_CLIENTE(P_FEC_HASTA); -- PSA002 LISTA DE CLIENTE (TODO)
         --tool_pro_log_proceso(SYSDATE,'FIN PR_GEN_ARC_LIS_CLIENTE','PSAML');
         commit;

         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_MOVIMIENTOS','PSAML');
         PR_GEN_ARC_MOVIMIENTOS(P_FEC_HASTA); -- PSA003 MOVIMIENTOS
         --tool_pro_log_proceso(SYSDATE,'FIN PR_GEN_ARC_MOVIMIENTOS','PSAML');

         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_RELACIONES','PSAML');
         PR_GEN_ARC_RELACIONES(P_FEC_HASTA); -- PSA004 RELACIONES
         --tool_pro_log_proceso(SYSDATE,'FIN PR_GEN_ARC_RELACIONES','PSAML');
         commit;

         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_PERFILES','PSAML');
         PR_GEN_ARC_PERFILES(P_FEC_HASTA); -- PSA005 DECLARACIONES
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_GEN_ARC_PERFILES', 'PSAML');
         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_CUENTAS','PSAML');
         PR_GEN_ARC_CUENTAS(P_FEC_HASTA); -- PSA006 PRODUCTOS
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_GEN_ARC_CUENTAS', 'PSAML');
         commit;
         --tool_pro_log_proceso(SYSDATE,'INICIO PR_GEN_ARC_CLIENTES','PSAML');
         PR_GEN_ARC_CLIENTES(P_FEC_HASTA); -- PSA007 CLIENTES
         --tool_pro_log_proceso(SYSDATE, 'FIN PR_GEN_ARC_CLIENTES', 'PSAML');
         --
         commit;
         --BORRAR AL PASAR A PRODUCCIÓN
         begin
            update psa007 t
               set t.psa007a1 = 'AAAAAAAAAAAA',
                   T.PSA007A2 = 'AAAAAAAAAAAA',
                   T.Psa007n2 = 'NNNNNNNNNNNN',
                   T.PSA007DN = 'NNNNNNNNNNNN';

            update psa006 t set t.psa006nc = 'NNNNNNNNNNNN';
         end;
         commit;
      ELSE
         RAISE_APPLICATION_ERROR(-20001,
                                 'Ya se proceso la fecha ' || V_FEC_PROCESO);
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al generar datos interfaces PSAML - ' ||
                                 sqlerrm);
   END;

  PROCEDURE PR_GEN_ARC_MOV_PIC(p_fec_desde date, p_fec_hasta date) IS

   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA023',SYSDATE,'N');

          BEGIN
             insert into psa023
               (psa023af,
                psa023au,
                psa023bi,
                psa023ca,
                psa023cb,
                psa023cd,
                psa023ci,
                psa023cl,
                psa023co,
                psa023cr,
                psa023ct,
                psa023da,
                psa023db,
                psa023dd,
                psa023dh,
                psa023dl,
                psa023do,
                psa023dr,
                psa023dt,
                psa023eb,
                psa023eo,
                psa023fc,
                psa023fi,
                psa023ft,
                psa023fu,
                psa023ht,
                psa023id,
                psa023it,
                psa023mc,
                psa023md,
                psa023ml,
                psa023mo,
                psa023mp,
                psa023mu,
                psa023nc,
                psa023op,
                psa023or,
                psa023os,
                psa023pa,
                psa023pd,
                psa023pr,
                psa023rf,
                psa023rl,
                psa023rv,
                psa023so,
                psa023st,
                psa023su,
                psa023ta,
                psa023td,
                psa023tp,
                psa023tr,
                psa023tt)

               Select
                psa003_HISaf,
                psa003_HISau,
                psa003_HISbi,
                psa003_HISca,
                psa003_HIScb,
                psa003_HIScd,
                psa003_HISci,
                psa003_HIScl,
                psa003_HISco,
                psa003_HIScr,
                psa003_HISct,
                psa003_HISda,
                psa003_HISdb,
                psa003_HISdd,
                psa003_HISdh,
                psa003_HISdl,
                psa003_HISdo,
                psa003_HISdr,
                psa003_HISdt,
                psa003_HISeb,
                psa003_HISeo,
                psa003_HISfc,
                psa003_HISfi,
                psa003_HISft,
                psa003_HISfu,
                psa003_HISht,
                psa003_HISid,
                'S',--indica que es del sistema ITGF
                psa003_HISmc,
                psa003_HISmd,
                psa003_HISml,
                psa003_HISmo,
                psa003_HISmp,
                psa003_HISmu,
                psa003_HISnc,
                psa003_HISop,
                psa003_HISor,
                psa003_HISos,
                psa003_HISpa,
                psa003_HISpd,
                psa003_HISpr,
                psa003_HISrf,
                psa003_HISrl,
                psa003_HISrv,
                psa003_HISso,
                psa003_HISst,
                psa003_HISsu,
                psa003_HISta,
                psa003_HIStd,
                psa003_HIStp,
                psa003_HIStr,
                psa003_HIStt

                --- PIDISTECNO-21721
                from psa003_HIS, psa006
                where TO_dATE(psa003_HISFT,'RRRRMMDD') between p_fec_desde and p_fec_hasta
                and psa003_HISnc = psa006ct
                and psa003_HISso = psa006so
                --Los canales "CAN-139, CAN-140 y CAN-66.
                --Solo consideramos como debitos, no asi como creditos.
                and ((psa003_HISca in (139,140,66)
                      and psa003_HISdh = 1)--mov debito (ajustado)
                     or (psa003_HISca not in (139,140,66)
                      and psa003_HISdh != 1)
                    )

                --Solamente los Productos PRO-21-GS, PRO-21-ME, PRO-20-GS,
                --PRO-20-ME, PRO-22-GS y PRO-22-ME. Consideramos como creditos y debitos,
                --por tanto, los demás productos solo consideramos como Creditos.
                and  ((psa006mo not in (20,21,22)
                      and psa003_HISdh = 2)--mov crédito
                      or (psa006mo in (20,21,22))
                     );
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error en la insercion en la tabla psa023 - Transacciones. ' || sqlerrm);
         END;

       commit;

   END;



     PROCEDURE PR_GEN_ARC_CLI_PIC(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
     --v_fec_Desde varchar2(8):= to_Char(p_fec_desde,'RRRRMMDD');
     --v_fec_hasta varchar2(8):= to_Char(p_fec_hasta,'RRRRMMDD');

     cursor c_cli is
     SELECT *
       FROM (select c.cod_persona,
                    lpad(p.nom_completo, 70) nom_completo,
                    p.tipo tip_persona,
                    pai_psa.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') cod_tip_documento,
                    p.nro_documento,
                    pai_psa.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento, p.cod_pais), 'BA_PAISES') cod_pai_documento,
                    c.fec_insercion,
                    c.fec_modificacion,
                    c.cod_seg_cliente,
                    p.cod_pais,
                    p.cod_actividad,
                    nvl(p.cod_rub_primario, '749905') cod_rub_primario
               from ge_clientes c, ba_personas p, (select distinct a.cod_persona from GE_CTA_IMP_PSAML a WHERE A.EXI_ENBANTOTAL = 'N') psa
              where c.cod_persona = p.cod_persona
                and c.cod_persona = psa.cod_persona) CLIS;


      v_segmento ge_seg_clientes.descripcion%type;
      --v_seg_cli_itgf varchar2(50);
      v_cod_pai_ori number(3);
      v_cod_pai_doc number(3);
      v_profesion ba_profesiones.descripcion%type;
      v_actividad ge_actividades.descripcion%type;
      v_ind_sin_fin_luc number(1);
      v_ind_pep number(1);
      v_fec_inf_ing_egr cr_per_ing_egresos.fec_informacion%type;
      v_des_pais ba_paises.descripcion%type;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA024',SYSDATE,'N');

      FOR c IN c_cli LOOP
        BEGIN
           select s.dom_ref_bantotal
             into v_segmento
             from mi_tab_parametricas s
            where s.nom_tab_itgf = 'GE_SEG_CLIENTES'
            and   s.val_cod_itgf =  c.cod_seg_cliente;
         EXCEPTION
            WHEN OTHERS THEN
               v_segmento := null;
         END;

         v_cod_pai_ori := PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pais, 'BA_PAISES');
         v_cod_pai_doc := c.cod_pai_Documento;

         if c.tip_persona = 'F' then
           begin
             select p.descripcion
               into v_profesion
               from ba_per_fisicas f, ba_profesiones p
              where f.cod_persona = c.cod_persona
                and f.cod_profesion = p.cod_profesion;
           exception
             when others then
               v_profesion := null;
           end;
           v_ind_sin_fin_luc := 0;
         else
           v_profesion := null;
           begin
             select decode(j.cod_ramo, 210, 1, 0)
               into v_ind_sin_fin_luc
               from ba_per_juridicas j
              where cod_persona = c.cod_persona;
           exception
             when others then
               v_ind_sin_fin_luc := 0;
           end;
         end if;

         BEGIN
           select s.descripcion
             into v_actividad
             from ge_actividades s
            where s.cod_actividad =  c.cod_actividad;
         EXCEPTION
            WHEN OTHERS THEN
               v_actividad := null;
         END;

         BEGIN
           select decode(FU_OBT_PEP(c.cod_persona), 'Y', 1, 0)
             into v_ind_pep
             from dual;
         EXCEPTION
            WHEN OTHERS THEN
               v_ind_pep := 0;
         END;

         begin
           select max(fec_informacion)
             into v_fec_inf_ing_egr
             from cr_per_ing_egresos
            where cod_persona = c.cod_persona;
         exception
           when others then
             v_fec_inf_ing_egr := null;
         end;

         begin
           select descripcion
             into v_des_pais
             from ba_paises p
            where p.cod_pais = c.cod_pais;
         exception
           when others then
             v_des_pais := null;
         end;

         begin
           insert into PSA024(PSA024FIN, PSA024FFI, PSA024PAI, PSA024TDO,
                              PSA024NDO, PSA024ENT, PSA024DEN, PSA024NCL,
                              PSA024TPE, PSA024SBA, PSA024SLA, PSA024VSL,
                              PSA024FAB, PSA024CPN, PSA024PNC, PSA024OCU,
                              PSA024AEC, PSA024OSL, PSA024FID, PSA024PEP,
                              PSA024LRE, PSA024FAF, PSA024FEI)
                      values( to_char(p_fec_desde,'RRRRMMDD'), to_char(p_fec_HASTA,'RRRRMMDD'), v_cod_pai_doc, to_number(c.cod_tip_documento),
                              c.nro_documento, 7, 'BBVA', trim(c.nom_completo),
                              c.tip_persona, v_segmento, 0, 0,
                              TO_CHAR(c.fec_modificacion,'RRRRMMDD'), v_cod_pai_ori, v_des_pais, v_profesion,
                              PAI_PSA.FU_OBT_COD_BTL_PSA(C.cod_rub_primario,'GE_RUB_ECONOMICOS')/*v_actividad*/, v_ind_sin_fin_luc, 0, v_ind_pep,
                              0, TO_CHAR(v_fec_inf_ing_egr,'RRRRMMDD'), TO_CHAR(v_fec_actual,'RRRRMMDD'));
          exception
            when others then

               raise_application_error(-20000, 'Error en la insercion en la tabla psa024 - Clientes. ' || sqlerrm);
          end;
       END LOOP;

       --marcar como cliente en lista
       --tool_pro_log_proceso(SYSDATE, 'ACTUALIZACIÓN P024 CLIENTE EN LISTA');
       begin
          update psa024 t set t.psa024lre = 1
          WHERE EXISTS (SELECT 'A' FROM PSA002 A
                        WHERE A.PSA002PA = T.PSA024PAI
                        AND   A.PSA002TO = T.PSA024TDO
                        AND   A.PSA002DO = T.PSA024NDO);
       end;
       --tool_pro_log_proceso(SYSDATE, 'ACTUALIZACIÓN P024 CLIENTE EN LISTA - FIN');



   END;
   
   PROCEDURE PR_GEN_ARC_CLI_PIC_CM(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
     --v_fec_Desde varchar2(8):= to_Char(p_fec_desde,'RRRRMMDD');
     --v_fec_hasta varchar2(8):= to_Char(p_fec_hasta,'RRRRMMDD');

     cursor c_cli is
     SELECT *
       FROM (select c.cod_persona,
                    lpad(p.nom_completo, 70) nom_completo,
                    p.tipo tip_persona,
                    pai_psa.FU_OBT_COD_BTL_PSA(p.cod_tip_documento, 'BA_TIP_DOCUMENTOS') cod_tip_documento,
                    p.nro_documento,
                    pai_psa.FU_OBT_COD_BTL_PSA(nvl(p.cod_pai_documento, p.cod_pais), 'BA_PAISES') cod_pai_documento,
                    c.fec_insercion,
                    c.fec_modificacion,
                    c.cod_seg_cliente,
                    p.cod_pais,
                    p.cod_actividad,
                    nvl(p.cod_rub_primario, '749905') cod_rub_primario
               from ge_clientes c, ba_personas p, (select distinct a.cod_persona from GE_CTA_IMP_PSAML a WHERE A.EXI_ENBANTOTAL = 'S') psa
              where c.cod_persona = p.cod_persona
                and c.cod_persona = psa.cod_persona) CLIS;


      v_segmento ge_seg_clientes.descripcion%type;
      --v_seg_cli_itgf varchar2(50);
      v_cod_pai_ori number(3);
      v_cod_pai_doc number(3);
      v_profesion ba_profesiones.descripcion%type;
      v_actividad ge_actividades.descripcion%type;
      v_ind_sin_fin_luc number(1);
      v_ind_pep number(1);
      v_fec_inf_ing_egr cr_per_ing_egresos.fec_informacion%type;
      v_des_pais ba_paises.descripcion%type;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA060',SYSDATE,'N');

      FOR c IN c_cli LOOP
        BEGIN
           select s.dom_ref_bantotal
             into v_segmento
             from mi_tab_parametricas s
            where s.nom_tab_itgf = 'GE_SEG_CLIENTES'
            and   s.val_cod_itgf =  c.cod_seg_cliente;
         EXCEPTION
            WHEN OTHERS THEN
               v_segmento := null;
         END;

         v_cod_pai_ori := PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pais, 'BA_PAISES');
         v_cod_pai_doc := c.cod_pai_Documento;

         if c.tip_persona = 'F' then
           begin
             select p.descripcion
               into v_profesion
               from ba_per_fisicas f, ba_profesiones p
              where f.cod_persona = c.cod_persona
                and f.cod_profesion = p.cod_profesion;
           exception
             when others then
               v_profesion := null;
           end;
           v_ind_sin_fin_luc := 0;
         else
           v_profesion := null;
           begin
             select decode(j.cod_ramo, 210, 1, 0)
               into v_ind_sin_fin_luc
               from ba_per_juridicas j
              where cod_persona = c.cod_persona;
           exception
             when others then
               v_ind_sin_fin_luc := 0;
           end;
         end if;

         BEGIN
           select s.descripcion
             into v_actividad
             from ge_actividades s
            where s.cod_actividad =  c.cod_actividad;
         EXCEPTION
            WHEN OTHERS THEN
               v_actividad := null;
         END;

         BEGIN
           select decode(FU_OBT_PEP(c.cod_persona), 'Y', 1, 0)
             into v_ind_pep
             from dual;
         EXCEPTION
            WHEN OTHERS THEN
               v_ind_pep := 0;
         END;

         begin
           select max(fec_informacion)
             into v_fec_inf_ing_egr
             from cr_per_ing_egresos
            where cod_persona = c.cod_persona;
         exception
           when others then
             v_fec_inf_ing_egr := null;
         end;

         begin
           select descripcion
             into v_des_pais
             from ba_paises p
            where p.cod_pais = c.cod_pais;
         exception
           when others then
             v_des_pais := null;
         end;

         begin
           insert into PSA060(PSA060FIN, PSA060FFI, PSA060PAI, PSA060TDO,
                              PSA060NDO, PSA060ENT, PSA060DEN, PSA060NCL,
                              PSA060TPE, PSA060SBA, PSA060SLA, PSA060VSL,
                              PSA060FAB, PSA060CPN, PSA060PNC, PSA060OCU,
                              PSA060AEC, PSA060OSL, PSA060FID, PSA060PEP,
                              PSA060LRE, PSA060FAF, PSA060FEI)
                      values( to_char(p_fec_desde,'RRRRMMDD'), to_char(p_fec_HASTA,'RRRRMMDD'), v_cod_pai_doc, to_number(c.cod_tip_documento),
                              c.nro_documento, 7, 'BBVA', trim(c.nom_completo),
                              c.tip_persona, v_segmento, 0, 0,
                              TO_CHAR(c.fec_modificacion,'RRRRMMDD'), v_cod_pai_ori, v_des_pais, v_profesion,
                              PAI_PSA.FU_OBT_COD_BTL_PSA(C.cod_rub_primario,'GE_RUB_ECONOMICOS')/*v_actividad*/, v_ind_sin_fin_luc, 0, v_ind_pep,
                              0, TO_CHAR(v_fec_inf_ing_egr,'RRRRMMDD'), TO_CHAR(v_fec_actual,'RRRRMMDD'));
          exception
            when others then

               raise_application_error(-20000, 'Error en la insercion en la tabla psa060 - Clientes. comunes' || sqlerrm);
          end;
       END LOOP;

       --marcar como cliente en lista
       --tool_pro_log_proceso(SYSDATE, 'ACTUALIZACIÓN P024 CLIENTE EN LISTA');
       begin
          update psa024 t set t.psa024lre = 1
          WHERE EXISTS (SELECT 'A' FROM PSA002 A
                        WHERE A.PSA002PA = T.PSA024PAI
                        AND   A.PSA002TO = T.PSA024TDO
                        AND   A.PSA002DO = T.PSA024NDO);
       end;
       --tool_pro_log_proceso(SYSDATE, 'ACTUALIZACIÓN P024 CLIENTE EN LISTA - FIN');



   END;


   PROCEDURE PR_GEN_ARC_PRO_PIC(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
     --v_fec_Desde varchar2(8):= to_Char(p_fec_desde,'RRRRMMDD');
     --v_fec_hasta varchar2(8):= to_Char(p_fec_hasta,'RRRRMMDD');
     v_hasta_anio varchar2(8):= to_Char(p_fec_hasta,'rrrr');
     v_hasta_mes varchar2(8):= to_Char(p_fec_hasta,'mm');
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA025',SYSDATE,'N');
      insert into psa025
   (PSA025FIN,
    PSA025FFI,
    PSA025PAI,
    PSA025TDO,
    PSA025NDO,
    PSA025CPR,
    PSA025NPR,
    PSA025ENT,
    PSA025DEN,
    PSA025VSL,
    PSA025TOC,
    PSA025COC,
    PSA025TOD,
    PSA025COD,
    PSA025SDO,
    PSA025VCM,
    PSA025FEI,
    PSA025VFP)
   select TO_CHAR(p_fec_desde, 'RRRRMMDD'),
          TO_CHAR(p_fec_hasta, 'RRRRMMDD'),
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pai_Documento,
                                      'BA_PAISES'),*/
          c.cod_pai_Documento,                            
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_tip_documento,
                                      'BA_TIP_DOCUMENTOS'),*/
          c.cod_tip_documento,                            
          c.nro_documento,
          c.cod_producto,
          c.des_producto,
          7,
          'BBVA',
          0,
          sum(c.mto_credito) mto_credito,
          sum(c.can_credito) can_credito,
          sum(c.mto_debito) mto_debito,
          sum(c.can_debito) can_debito,
          sum(c.sal_periodo) sal_periodo,
          sum(c.cuo_periodo) cuo_periodo,
          TO_CHAR(v_Fec_Actual, 'RRRRMMDD'),
          0
   --*
     from (select c.cod_persona,
                  p.cod_pais,
                  --nvl(p.cod_pai_documento, p.cod_pais) cod_pai_documento,
                  tot_mov.psa023pa cod_pai_documento, 
                  --p.cod_tip_documento,
                  tot_mov.psa023td cod_tip_documento,
                  --p.nro_documento,
                  TOT_MOV.psa023do nro_documento,
                  --TODX: por el momento mandamos 20 mientras se espera la equivalencia de modulo productos
                  /*'PRO' || '-' || 20\*decode(c.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5) *\|| '-' || cu.cod_moneda||'-'||pai_psa.FU_OBT_NRO_SUB_OPERACION(p.COD_PERSONA,
                                                   c.nro_cuenta) cod_producto,*/
                  --'PRO' || '-' || PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_modulo, c.cod_modalidad, 'MODULOS_PRODUCTOS')|| '-' || decode(cu.cod_moneda,'GS','GS','ME') cod_producto,
                  'PRO' || '-' || tp.val_cod_bantotal || '-' || decode(cu.cod_moneda,'GS','GS','ME') cod_producto,
                  --md.descripcion des_producto,
                  tp.observacion des_producto,
                  c.cod_modulo,
                  c.cod_modalidad,
                  c.nro_cuenta,
                  7 || lpad(c.COD_PERSONA, 8, 0) btl_cuenta,
                  pai_psa.FU_OBT_NRO_SUB_OPERACION(p.COD_PERSONA,
                                                   c.nro_cuenta) btl_sub_cuenta,
                  TOT_MOV.can_credito,
                  TOT_MOV.can_debito,
                  TOT_MOV.mto_credito,
                  TOT_MOV.mto_debito,
                  nvl((case
                         when cu.cod_modulo = 3 then
                          (select t.sal_fin_mes
                             from ah_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 4 then
                          (select t.sal_fin_mes
                             from cc_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 5 then
                          (select t.sal_financiado + t.sal_facturado +
                                  t.sal_facturar + t.sal_cuo_pendientes
                             from ta_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 6 then
                          (select t.sal_cap_actual + t.sal_int_actual
                             from pr_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 15 then
                          (select t.sal_total
                             from ov_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         else
                          0
                      end),
                      0) sal_periodo,
                  (case
                     when cu.cod_modulo = 6 then
                      (select sum(p.mto_capital + p.mto_interes)
                         from pr_cuotas p
                        where nro_cuenta = c.nro_cuenta
                          and p.fec_vencimiento between
                              p_fec_desde and
                              p_fec_hasta)
                     else
                      0
                  end) cuo_periodo

             from ge_cta_clientes c,
                  ba_personas     p,
                  ge_cuentas      cu,
                  ge_modalidades  mo,
                  ba_modulos md,
                  ge_est_cuentas  e,
                  mi_tab_parametricas tp,
                  --MOV TOTALIZADO POR CUENTA Y SUB CUENTA
                  (select m.psa023nc,
                          m.psa023so,
                          m.psa023do,--nro_documento del mov
                          m.psa023pa,-- pais 
                          m.psa023td,--tip doc
                          mct.cod_persona,
                          mct.nro_cta_itgf,
                          sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
                          sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
                          sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
                          sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito
                     from psa023 m, mi_cta_clientes mct
                    where TO_dATE(PSA023FT, 'RRRRMMDD') between
                          p_fec_desde and
                          p_fec_hasta
                      and m.psa023rv = 'N'
                      and m.psa023nc is not null
                      and m.psa023nc = mct.nro_cta_bantotal
                      AND M.PSA023SO = MCT.NRO_SUB_CTA_BANTOTAL
                      --and m.psa023tt not in (999,998)
                    GROUP BY m.psa023nc, m.psa023so, m.psa023do, m.psa023pa, m.psa023td, mct.cod_persona, mct.nro_cta_itgf) TOT_MOV

            where c.cod_persona = p.cod_persona
              and c.nro_cuenta = cu.nro_cuenta
              and c.relacion = 'P'
              and cu.cod_modulo = mo.cod_modulo
              and cu.cod_modalidad = mo.cod_modalidad
              and cu.cod_modulo = e.cod_modulo
              and cu.cod_modalidad = e.cod_modalidad
              and cu.estado = e.estado
              and mo.cod_modulo = md.cod_modulo
              and c.cod_modulo = tp.val_cod_itgf (+)
              and c.cod_modalidad = tp.val_cod_itgf2 (+)
              and  'MODULOS_PRODUCTOS' = tp.nom_tab_itgf (+)



              and c.cod_persona = tot_mov.cod_persona
              and c.nro_cuenta = tot_mov.nro_cta_itgf

              and exists
            (select 's'
                     from GE_CTA_IMP_PSAML a
                    where a.cod_persona = c.cod_persona
                      AND A.NRO_CUENTA = C.NRO_CUENTA
                      and a.exi_enbantotal = 'N'
                      and rownum = 1)
              and (e.activo = 'S' or
                  (e.activo = 'N' and cu.fec_modificacion >= p_fec_desde ))) c
        group by
          TO_CHAR(p_fec_desde, 'RRRRMMDD'),
          TO_CHAR(p_fec_hasta, 'RRRRMMDD'),
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pai_documento,
                                      'BA_PAISES'),*/
          c.cod_pai_documento,                            
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_tip_documento,
                                      'BA_TIP_DOCUMENTOS'),*/
          c.cod_tip_documento,                            
          c.nro_documento,
          c.cod_producto,
          c.des_producto;


   exception
     when others then
        raise_application_error(-20000, 'Error en la insercion en la tabla psa025 - Productos. ' || sqlerrm);


   END;
   
   --CLIENTES COMUNES
   PROCEDURE PR_GEN_ARC_PRO_PIC_CM(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
     --v_fec_Desde varchar2(8):= to_Char(p_fec_desde,'RRRRMMDD');
     --v_fec_hasta varchar2(8):= to_Char(p_fec_hasta,'RRRRMMDD');
     v_hasta_anio varchar2(8):= to_Char(p_fec_hasta,'rrrr');
     v_hasta_mes varchar2(8):= to_Char(p_fec_hasta,'mm');
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA058',SYSDATE,'N');
      insert into PSA058
         (PSA058FIN,
          PSA058FFI,
          PSA058PAI,
          PSA058TDO,
          PSA058NDO,
          PSA058CPR,
          PSA058NPR,
          PSA058ENT,
          PSA058DEN,
          PSA058VSL,
          PSA058TOC,
          PSA058COC,
          PSA058TOD,
          PSA058COD,
          PSA058SDO,
          PSA058VCM,
          PSA058FEI,
          PSA058VFP)
   select TO_CHAR(p_fec_desde, 'RRRRMMDD'),
          TO_CHAR(p_fec_hasta, 'RRRRMMDD'),
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pai_Documento,
                                      'BA_PAISES'),*/
          c.cod_pai_Documento,                            
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_tip_documento,
                                      'BA_TIP_DOCUMENTOS'),*/
          c.cod_tip_documento,                            
          c.nro_documento,
          c.cod_producto,
          c.des_producto,
          7,
          'BBVA',
          0,
          sum(c.mto_credito) mto_credito,
          sum(c.can_credito) can_credito,
          sum(c.mto_debito) mto_debito,
          sum(c.can_debito) can_debito,
          sum(c.sal_periodo) sal_periodo,
          sum(c.cuo_periodo) cuo_periodo,
          TO_CHAR(v_Fec_Actual, 'RRRRMMDD'),
          0
   --*
     from (select c.cod_persona,
                  p.cod_pais,
                  --nvl(p.cod_pai_documento, p.cod_pais) cod_pai_documento,
                  tot_mov.psa023pa cod_pai_documento, 
                  --p.cod_tip_documento,
                  tot_mov.psa023td cod_tip_documento,
                  --p.nro_documento,
                  TOT_MOV.psa023do nro_documento,
                  --TODX: por el momento mandamos 20 mientras se espera la equivalencia de modulo productos
                  /*'PRO' || '-' || 20\*decode(c.cod_modulo, 4, 20, 3, 21, 5, 35, 6, 30, 8, 5) *\|| '-' || cu.cod_moneda||'-'||pai_psa.FU_OBT_NRO_SUB_OPERACION(p.COD_PERSONA,
                                                   c.nro_cuenta) cod_producto,*/
                  --'PRO' || '-' || PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_modulo, c.cod_modalidad, 'MODULOS_PRODUCTOS')|| '-' || decode(cu.cod_moneda,'GS','GS','ME') cod_producto,
                  'PRO' || '-' || tp.val_cod_bantotal || '-' || decode(cu.cod_moneda,'GS','GS','ME') cod_producto,
                  --md.descripcion des_producto,
                  tp.observacion des_producto,
                  c.cod_modulo,
                  c.cod_modalidad,
                  c.nro_cuenta,
                  7 || lpad(c.COD_PERSONA, 8, 0) btl_cuenta,
                  pai_psa.FU_OBT_NRO_SUB_OPERACION(p.COD_PERSONA,
                                                   c.nro_cuenta) btl_sub_cuenta,
                  TOT_MOV.can_credito,
                  TOT_MOV.can_debito,
                  TOT_MOV.mto_credito,
                  TOT_MOV.mto_debito,
                  nvl((case
                         when cu.cod_modulo = 3 then
                          (select t.sal_fin_mes
                             from ah_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 4 then
                          (select t.sal_fin_mes
                             from cc_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 5 then
                          (select t.sal_financiado + t.sal_facturado +
                                  t.sal_facturar + t.sal_cuo_pendientes
                             from ta_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 6 then
                          (select t.sal_cap_actual + t.sal_int_actual
                             from pr_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         when cu.cod_modulo = 15 then
                          (select t.sal_total
                             from ov_sal_mensuales t
                            where nro_cuenta = c.nro_cuenta
                              and t.ano = v_hasta_anio
                              and t.mes = v_hasta_mes)
                         else
                          0
                      end),
                      0) sal_periodo,
                  (case
                     when cu.cod_modulo = 6 then
                      (select sum(p.mto_capital + p.mto_interes)
                         from pr_cuotas p
                        where nro_cuenta = c.nro_cuenta
                          and p.fec_vencimiento between
                              p_fec_desde and
                              p_fec_hasta)
                     else
                      0
                  end) cuo_periodo

             from ge_cta_clientes c,
                  ba_personas     p,
                  ge_cuentas      cu,
                  ge_modalidades  mo,
                  ba_modulos md,
                  ge_est_cuentas  e,
                  mi_tab_parametricas tp,
                  --MOV TOTALIZADO POR CUENTA Y SUB CUENTA
                  (select m.psa023nc,
                          m.psa023so,
                          m.psa023do,--nro_documento del mov
                          m.psa023pa,-- pais 
                          m.psa023td,--tip doc
                          mct.cod_persona,
                          mct.nro_cta_itgf,
                          sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
                          sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
                          sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
                          sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito
                     from psa023 m, mi_cta_clientes mct
                    where TO_dATE(PSA023FT, 'RRRRMMDD') between
                          p_fec_desde and
                          p_fec_hasta
                      and m.psa023rv = 'N'
                      and m.psa023nc is not null
                      and m.psa023nc = mct.nro_cta_bantotal
                      AND M.PSA023SO = MCT.NRO_SUB_CTA_BANTOTAL
                      --and m.psa023tt not in (999,998)
                    GROUP BY m.psa023nc, m.psa023so, m.psa023do, m.psa023pa, m.psa023td, mct.cod_persona, mct.nro_cta_itgf) TOT_MOV

            where c.cod_persona = p.cod_persona
              and c.nro_cuenta = cu.nro_cuenta
              and c.relacion = 'P'
              and cu.cod_modulo = mo.cod_modulo
              and cu.cod_modalidad = mo.cod_modalidad
              and cu.cod_modulo = e.cod_modulo
              and cu.cod_modalidad = e.cod_modalidad
              and cu.estado = e.estado
              and mo.cod_modulo = md.cod_modulo
              and c.cod_modulo = tp.val_cod_itgf (+)
              and c.cod_modalidad = tp.val_cod_itgf2 (+)
              and  'MODULOS_PRODUCTOS' = tp.nom_tab_itgf (+)



              and c.cod_persona = tot_mov.cod_persona
              and c.nro_cuenta = tot_mov.nro_cta_itgf

              and exists
            (select 's'
                     from GE_CTA_IMP_PSAML a
                    where a.cod_persona = c.cod_persona
                      AND A.NRO_CUENTA = C.NRO_CUENTA
                      and a.exi_enbantotal = 'S'
                      and rownum = 1)
              and (e.activo = 'S' or
                  (e.activo = 'N' and cu.fec_modificacion >= p_fec_desde ))) c
        group by
          TO_CHAR(p_fec_desde, 'RRRRMMDD'),
          TO_CHAR(p_fec_hasta, 'RRRRMMDD'),
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_pai_documento,
                                      'BA_PAISES'),*/
          c.cod_pai_documento,                            
          /*PAI_PSA.FU_OBT_COD_BTL_PSA(c.cod_tip_documento,
                                      'BA_TIP_DOCUMENTOS'),*/
          c.cod_tip_documento,                            
          c.nro_documento,
          c.cod_producto,
          c.des_producto;


   exception
     when others then
        raise_application_error(-20000, 'Error en la insercion en la tabla psa058 - Productos.CLIENTES COMUNES ' || sqlerrm);


   END;

   PROCEDURE PR_GEN_ARC_CAN_PIC(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

     cursor c_can is
     select m.psa023td cod_tip_documento,
            m.psa023do nro_documento,
            --p.nro_documento nro_documento,
            m.psa023pa cod_pais,
            'CAN' || '-' || m.psa023ca cod_canal,
            t.descripcion des_canal,
            sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
            sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
            sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
            sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito
       from psa023              m,
            mi_tab_parametricas t,
            GE_CTA_IMP_PSAML    a,
            Mi_Cta_Clientes     mct
            --BA_PERSONAS P
      where TO_dATE(PSA023FT, 'RRRRMMDD') between p_fec_desde and p_fec_hasta
        and m.psa023rv = 'N' -- que no estee reversado
        and t.nom_tab_itgf = 'PSAML_CANALES'
        and t.val_cod_bantotal = m.psa023ca
        and m.psa023do is not null -- forzar a solor registros de personas
           /*and a.cod_persona = TO_NUMBER(substr(m.psa023nc, -7))
           and a.nro_cuenta =
             pai_psa.FU_OBT_NRO_CTA_ITGF(a.cod_persona, m.psa023so)*/
           
        and m.psa023nc = mct.nro_cta_bantotal
        and m.psa023so = mct.nro_sub_cta_bantotal
        and mct.cod_persona = a.cod_persona
        and mct.nro_cta_itgf = a.nro_cuenta
        --and mct.cod_persona = p.cod_persona
           
        and a.exi_enbantotal = 'N'
     /*and exists (select 's'
      from GE_CTA_IMP_PSAML a
     where a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
       and a.exi_enbantotal = 'N'
       and rownum = 1)*/
      group by m.psa023td,
               m.psa023do,
               --p.nro_documento,
               m.psa023pa,
               m.psa023ca,
               t.descripcion;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA026',SYSDATE,'N');
      FOR c IN c_can LOOP
         begin
           insert into psa026(PSA026FIN, PSA026FFI, PSA026PAI, PSA026TDO,
                              PSA026NDO, PSA026CCA, PSA026NCA, PSA026ENT,
                              PSA026DEN, PSA026VSL, PSA026TOC, PSA026COC,
                              PSA026TOD, PSA026COD, PSA026FEI, PSA026VFC)
            values(to_char(p_fec_desde,'RRRRMMDD'), to_Char(p_fec_hasta,'RRRRMMDD'), c.cod_pais, c.cod_tip_documento,
                   c.nro_documento, c.cod_canal, c.des_canal, 7,
                   'BBVA', 0, c.mto_credito, c.can_credito,
                   c.mto_debito, c.can_debito, to_char(v_fec_actual,'RRRRMMDD'), 0);
          exception
            when others then
               raise_application_error(-20000, 'Error en la insercion en la tabla psa026 - Canales. ' || sqlerrm);
          end;
       END LOOP;
   END;
   
   PROCEDURE PR_GEN_ARC_CAN_PIC_CM(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

     cursor c_can is
     select m.psa023td cod_tip_documento,
            m.psa023do nro_documento,
            --p.nro_documento nro_documento,
            m.psa023pa cod_pais,
            'CAN' || '-' || m.psa023ca cod_canal,
            t.descripcion des_canal,
            sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
            sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
            sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
            sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito
       from psa023              m,
            mi_tab_parametricas t,
            GE_CTA_IMP_PSAML    a,
            Mi_Cta_Clientes     mct
            --BA_PERSONAS P
      where TO_dATE(PSA023FT, 'RRRRMMDD') between p_fec_desde and p_fec_hasta
        and m.psa023rv = 'N' -- que no estee reversado
        and t.nom_tab_itgf = 'PSAML_CANALES'
        and t.val_cod_bantotal = m.psa023ca
        and m.psa023do is not null -- forzar a solor registros de personas
           /*and a.cod_persona = TO_NUMBER(substr(m.psa023nc, -7))
           and a.nro_cuenta =
             pai_psa.FU_OBT_NRO_CTA_ITGF(a.cod_persona, m.psa023so)*/
           
        and m.psa023nc = mct.nro_cta_bantotal
        and m.psa023so = mct.nro_sub_cta_bantotal
        and mct.cod_persona = a.cod_persona
        and mct.nro_cta_itgf = a.nro_cuenta
        --and mct.cod_persona = p.cod_persona
           
        and a.exi_enbantotal = 'S'
     /*and exists (select 's'
      from GE_CTA_IMP_PSAML a
     where a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
       and a.exi_enbantotal = 'N'
       and rownum = 1)*/
      group by m.psa023td,
               m.psa023do,
               --p.nro_documento,
               m.psa023pa,
               m.psa023ca,
               t.descripcion;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA057',SYSDATE,'N');
      FOR c IN c_can LOOP
         begin
           insert into PSA057(PSA057FIN, PSA057FFI, PSA057PAI, PSA057TDO,
                              PSA057NDO, PSA057CCA, PSA057NCA, PSA057ENT,
                              PSA057DEN, PSA057VSL, PSA057TOC, PSA057COC,
                              PSA057TOD, PSA057COD, PSA057FEI, PSA057VFC)
            values(to_char(p_fec_desde,'RRRRMMDD'), to_Char(p_fec_hasta,'RRRRMMDD'), c.cod_pais, c.cod_tip_documento,
                   c.nro_documento, c.cod_canal, c.des_canal, 7,
                   'BBVA', 0, c.mto_credito, c.can_credito,
                   c.mto_debito, c.can_debito, to_char(v_fec_actual,'RRRRMMDD'), 0);
          exception
            when others then
               raise_application_error(-20000, 'Error en la insercion en la tabla psa057 - Canales. clientes comunes ' || sqlerrm);
          end;
       END LOOP;
   END;

   PROCEDURE PR_GEN_ARC_SUC_PIC(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

     cursor c_suc is
      select m.psa023td cod_tip_documento,
             m.psa023do nro_documento,
             --p.nro_documento nro_documento,
             m.psa023pa cod_pais,
             'JUR' || '-' || m.psa023su cod_sucursal,
             (SELECT PM.DESCRIPCION
                FROM MI_TAB_PARAMETRICAS PM
               WHERE PM.NOM_TAB_ITGF = 'BA_OFICINAS'
                 AND PM.VAL_COD_BANTOTAL = M.PSA023SU
                 AND ROWNUM = 1) des_sucursal,
             sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
             sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
             sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
             sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito,
             sum(CASE
                    WHEN m.psa023ml > 10000000 THEN
                     1
                    ELSE
                     0
                 END) can_ope_may_10mill,
             sum(CASE
                    WHEN m.psa023ml > 10000000 THEN
                     m.psa023ml
                    ELSE
                     0
                 END) mto_ope_may_10mill
        from psa023           m,
             ge_cta_imp_psaml a,
             Mi_Cta_Clientes  mct
             --ba_personas p
       where TO_dATE(PSA023FT, 'RRRRMMDD') between p_fec_desde and p_fec_hasta
         and m.psa023rv = 'N' -- que no estee reversado
            --and m.psa023su = s.cod_oficina
         and m.psa023do is not null -- forzar a solor registros de personas
            
            /*and a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
            and a.nro_cuenta =
                pai_psa.FU_OBT_NRO_CTA_ITGF(a.cod_persona, m.psa023so)*/
         and m.psa023nc = mct.nro_cta_bantotal
         and m.psa023so = mct.nro_sub_cta_bantotal
         and mct.cod_persona = a.cod_persona
         and mct.nro_cta_itgf = a.nro_cuenta
         --and mct.cod_persona = p.cod_persona
            
         and a.exi_enbantotal = 'N'
      
      /*and exists (select 's'
       from
      where a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
        and a.exi_enbantotal = 'N'
        and rownum = 1)   */
       group by m.psa023td,
                m.psa023do,
                --p.nro_documento,
                m.psa023pa,
                m.psa023su;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA027',SYSDATE,'N');
      FOR c IN c_suc LOOP
         begin
           insert into PSA027(PSA027FIN, PSA027FFI, PSA027PAI, PSA027TDO,
                              PSA027NDO, PSA027CJU, PSA027NJU, PSA027ENT,
                              PSA027DEN, PSA027VSL, PSA027TOC, PSA027COC,
                              PSA027TOD, PSA027COD, PSA027TTS, PSA027CTS,
                              PSA027FEI, PSA027VFJ)
            values(to_char(p_fec_desde,'RRRRMMDD'), to_Char(p_fec_hasta,'RRRRMMDD'), c.cod_pais, c.cod_tip_documento,
                   c.nro_documento, c.cod_sucursal, c.des_sucursal, 7,
                   'BBVA', 0, c.mto_credito, c.can_credito,
                   c.mto_debito, c.can_debito, c.mto_ope_may_10mill, c.can_ope_may_10mill,
                   to_char(v_fec_actual,'RRRRMMDD'), 0);
          exception
            when others then
               raise_application_error(-20000, 'Error en la insercion en la tabla psa027 - Sucursales ' || sqlerrm);
          end;
       END LOOP;
       --se actualiza el nombre de sucursal para unificar con el de bantotal
       update psa027 t set t.psa027nju = 'Casa Central'
       where t.psa027cju = 'JUR-1';
   END;
   
   PROCEDURE PR_GEN_ARC_SUC_PIC_CM(p_fec_desde date, p_fec_hasta date) IS
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

     cursor c_suc is
     select m.psa023td cod_tip_documento,
             m.psa023do nro_documento,
             --p.nro_documento nro_documento,
             m.psa023pa cod_pais,
             'JUR' || '-' || m.psa023su cod_sucursal,
             (SELECT PM.DESCRIPCION
                FROM MI_TAB_PARAMETRICAS PM
               WHERE PM.NOM_TAB_ITGF = 'BA_OFICINAS'
                 AND PM.VAL_COD_BANTOTAL = M.PSA023SU
                 AND ROWNUM = 1) des_sucursal,
             sum(decode(m.psa023dh, 2, 1, 0)) can_credito,
             sum(decode(m.psa023dh, 1, 1, 0)) can_debito,
             sum(decode(m.psa023dh, 2, m.PSA023ML, 0)) mto_credito,
             sum(decode(m.psa023dh, 1, m.PSA023ML, 0)) mto_debito,
             sum(CASE
                    WHEN m.psa023ml > 10000000 THEN
                     1
                    ELSE
                     0
                 END) can_ope_may_10mill,
             sum(CASE
                    WHEN m.psa023ml > 10000000 THEN
                     m.psa023ml
                    ELSE
                     0
                 END) mto_ope_may_10mill
        from psa023           m,
             ge_cta_imp_psaml a,
             Mi_Cta_Clientes  mct
             --ba_personas p
       where TO_dATE(PSA023FT, 'RRRRMMDD') between p_fec_desde and p_fec_hasta
         and m.psa023rv = 'N' -- que no estee reversado
            --and m.psa023su = s.cod_oficina
         and m.psa023do is not null -- forzar a solor registros de personas
            
            /*and a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
            and a.nro_cuenta =
                pai_psa.FU_OBT_NRO_CTA_ITGF(a.cod_persona, m.psa023so)*/
         and m.psa023nc = mct.nro_cta_bantotal
         and m.psa023so = mct.nro_sub_cta_bantotal
         and mct.cod_persona = a.cod_persona
         and mct.nro_cta_itgf = a.nro_cuenta
         --and mct.cod_persona = p.cod_persona
            
         and a.exi_enbantotal = 'S'
      
      /*and exists (select 's'
       from
      where a.cod_persona = TO_NUMBER(substr(psa023nc, -6))
        and a.exi_enbantotal = 'N'
        and rownum = 1)   */
       group by m.psa023td,
                m.psa023do,
                --p.nro_documento,
                m.psa023pa,
                m.psa023su;
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --seteamos que los decimales sean PUNTOS
      pre_cam_for_numerico('.,');
      PR_PRE_PRO_REGISTROS('PSA059',SYSDATE,'N');
      FOR c IN c_suc LOOP
         begin
           insert into PSA059(PSA059FIN, PSA059FFI, PSA059PAI, PSA059TDO,
                              PSA059NDO, PSA059CJU, PSA059NJU, PSA059ENT,
                              PSA059DEN, PSA059VSL, PSA059TOC, PSA059COC,
                              PSA059TOD, PSA059COD, PSA059TTS, PSA059CTS,
                              PSA059FEI, PSA059VFJ)
            values(to_char(p_fec_desde,'RRRRMMDD'), to_Char(p_fec_hasta,'RRRRMMDD'), c.cod_pais, c.cod_tip_documento,
                   c.nro_documento, c.cod_sucursal, c.des_sucursal, 7,
                   'BBVA', 0, c.mto_credito, c.can_credito,
                   c.mto_debito, c.can_debito, c.mto_ope_may_10mill, c.can_ope_may_10mill,
                   to_char(v_fec_actual,'RRRRMMDD'), 0);
          exception
            when others then
               raise_application_error(-20000, 'Error en la insercion en la tabla psa027 - Sucursales clientes comunes' || sqlerrm);
          end;
       END LOOP;
       --se actualiza el nombre de sucursal para unificar con el de bantotal
       update PSA059 t set t.PSA059nju = 'Casa Central'
       where t.PSA059cju = 'JUR-1';
   END;

   PROCEDURE PR_REP_PRO_PIC(p_fec_desde date, p_fec_hasta date) IS
      v_fec_Desde varchar2(8):= to_Char(p_fec_desde,'RRRRMMDD');
      v_fec_hasta varchar2(8):= to_Char(p_fec_hasta,'RRRRMMDD');
   BEGIN
      PR_LOG_PSAML('PR_REP_PRO_PIC','P_FEC_DESDE', to_char(p_fec_desde));
      PR_LOG_PSAML('PR_REP_PRO_PIC','P_FEC_HASTA', to_char(p_fec_hasta));
      PR_LOG_PSAML('PR_REGEN_DAT_PSAML','FECHA DE REPROCESO', to_char(sysdate));
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      --borrado de datos de la fecha a reprocesar
      PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE DATOS', 'INICIO');
      begin

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA023');
         delete from psa023 t where to_Date(t.psa023FT, 'RRRRMMDD') between p_fec_desde and p_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA024');
         delete psa024 t
          where t.psa024fin = v_fec_Desde
            and t.psa024ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA025');
         delete psa025 t
          where t.psa025fin = v_fec_Desde
            and t.psa025ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA026');
         delete psa026 t
          where t.psa026fin = v_fec_Desde
            and t.psa026ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA027');
         delete psa027 t
          where t.psa027fin = v_fec_Desde
            and t.psa027ffi = v_fec_hasta;
         
         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA057');
         --Clientes comunes
         delete psa057 t
          where t.psa057fin = v_fec_Desde
            and t.psa057ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA058');
         delete psa058 t
          where t.psa058fin = v_fec_Desde
            and t.psa058ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA059');
         delete psa059 t
          where t.psa059fin = v_fec_Desde
            and t.psa059ffi = v_fec_hasta;

         PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE TABLA', 'PSA060');
         delete psa060 t
          where t.psa060fin = v_fec_Desde
            and t.psa060ffi = v_fec_hasta;

      exception
         when others then
            RAISE_APPLICATION_ERROR(-20001, 'Error al limpiar datos para reprocesar PIC. ' || sqlerrm);

      end;
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','BORRADO DE DATOS', 'FIN');


      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_MOV_PIC', 'INICIO');
      PR_GEN_ARC_MOV_PIC(p_fec_desde, p_fec_hasta);
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_PRO_PIC', 'INICIO');
      PR_GEN_ARC_PRO_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_PRO_PIC_CM', 'INICIO');
      PR_GEN_ARC_PRO_PIC_CM(p_fec_desde, p_fec_hasta);
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_CLI_PIC', 'INICIO');
      PR_GEN_ARC_CLI_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_CLI_PIC_CM', 'INICIO');
      PR_GEN_ARC_CLI_PIC_CM(p_fec_desde, p_fec_hasta);
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_CAN_PIC', 'INICIO');
      PR_GEN_ARC_CAN_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_CAN_PIC_CM', 'INICIO');
      PR_GEN_ARC_CAN_PIC_CM(p_fec_desde, p_fec_hasta);
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_SUC_PIC', 'INICIO');
      PR_GEN_ARC_SUC_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_REP_PRO_PIC','PR_GEN_ARC_SUC_PIC_CM', 'INICIO');
      PR_GEN_ARC_SUC_PIC_CM(p_fec_desde, p_fec_hasta);
      commit;
      PR_ENV_MAIL(p_fec_hasta,'PIC');
      commit;
      PR_LOG_PSAML('PR_REP_PRO_PIC','COMMIT', 'FIN');
   END;

   PROCEDURE PR_PRO_PIC(p_fec_desde date, p_fec_hasta date) IS
   BEGIN
      PR_LOG_PSAML('PR_PRO_PIC','P_FEC_DESDE', to_char(p_fec_desde));
      PR_LOG_PSAML('PR_PRO_PIC','P_FEC_HASTA', to_char(p_fec_hasta));
      PR_LOG_PSAML('PR_REGEN_DAT_PSAML','FECHA DE PROCESO', to_char(sysdate));
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_MOV_PIC', 'INICIO');
      PR_GEN_ARC_MOV_PIC(p_fec_desde, p_fec_hasta);
      commit;
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_PRO_PIC', 'INICIO');
      PR_GEN_ARC_PRO_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_PRO_PIC_CM', 'INICIO');
      PR_GEN_ARC_PRO_PIC_CM(p_fec_desde, p_fec_hasta);--CLIENTES COMUNES
      commit;
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_CLI_PIC', 'INICIO');
      PR_GEN_ARC_CLI_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_CLI_PIC_CM', 'INICIO');
      PR_GEN_ARC_CLI_PIC_CM(p_fec_desde, p_fec_hasta);--CLIENTES COMUNES
      commit;
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_CAN_PIC', 'INICIO');
      PR_GEN_ARC_CAN_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_CAN_PIC_CM', 'INICIO');
      PR_GEN_ARC_CAN_PIC_CM(p_fec_desde, p_fec_hasta);--CLIENTES COMUNES
      commit;
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_SUC_PIC', 'INICIO');
      PR_GEN_ARC_SUC_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_PRO_PIC','PR_GEN_ARC_SUC_PIC_CM', 'INICIO');
      PR_GEN_ARC_SUC_PIC_CM(p_fec_desde, p_fec_hasta);--CLIENTES COMUNES
      commit;
      PR_ENV_MAIL(p_fec_hasta,'PIC');
      commit;
      PR_LOG_PSAML('PR_PRO_PIC','COMMIT', 'FIN');

   END;

   PROCEDURE PR_PRO_AUX_PIC(p_fec_desde date, p_fec_hasta date) IS
   BEGIN
      -- Inicializar variables de entorno ITGF
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      PR_LOG_PSAML('INICIO PIC', 'DESDE: ' || P_fEC_dESDE || ' - HASTA: ' ||P_FEC_HASTA,'PIC');

      --logtest(sysdate, 'PR_GEN_ARC_MOV_PIC - INICIO ', 'PIC');
      PR_GEN_ARC_MOV_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_MOV_PIC','FIN', 'PIC');
      COMMIT;
      
      --logtest(sysdate, 'PR_GEN_ARC_PRO_PIC - INICIO ', 'PIC');
      PR_GEN_ARC_PRO_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_PRO_PIC','INICIO', 'PIC');
      PR_GEN_ARC_PRO_PIC_CM(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_PRO_PIC_CM','FIN', 'PIC');
      COMMIT;
      
      PR_GEN_ARC_CLI_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_CLI_PIC','INICIO', 'PIC');
      PR_GEN_ARC_CLI_PIC_CM(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_CLI_PIC_CM','FIN', 'PIC');
      COMMIT;

      PR_GEN_ARC_CAN_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_CAN_PIC','INICIO', 'PIC');
      PR_GEN_ARC_CAN_PIC_CM(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_CAN_PIC_CM','FIN', 'PIC');
      COMMIT;

      PR_GEN_ARC_SUC_PIC(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_SUC_PIC','INICIO', 'PIC');
      PR_GEN_ARC_SUC_PIC_CM(p_fec_desde, p_fec_hasta);
      PR_LOG_PSAML('PR_GEN_ARC_SUC_PIC_CM','FIN', 'PIC');
      COMMIT;
   END;

   --Procedure PIC MENSUAL
   PROCEDURE PR_GEN_PRO_PIC IS
      v_Desde date;
      v_hasta date;
   BEGIN
      v_desde := '01/'||TO_CHAR(PAG_CAL.FU_OBT_FEC_ACTUAL(4),'MM/RRRR');
      v_hasta := LAST_DAY(PAG_CAL.FU_OBT_FEC_ACTUAL(4));

      PR_PRO_PIC(v_Desde, v_hasta);

   END;

   --Procedure PIC para procesar un mes entero para regularización de los datos
   PROCEDURE PR_GEN_PRO_PIC_REG IS
      v_Desde date := to_date(fug_obt_pardinamico('FEC_PRO_REG_PIC_DESDE'),'dd/mm/rrrr');
      v_hasta date := to_date(fug_obt_pardinamico('FEC_PRO_REG_PIC_HASTA'),'dd/mm/rrrr');
   BEGIN

      PR_GEN_ARC_MOV_MASIVOS(v_Desde, v_hasta);
      PR_PRO_PIC(v_Desde, v_hasta);
      PR_TRU_TAB_BANTOTAL;--trunca las tablas bantotal

   END;




END PAI_PSA;
/

