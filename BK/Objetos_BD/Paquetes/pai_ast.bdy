CREATE OR REPLACE PACKAGE BODY IT.PAI_AST IS
  -- Paquete utilizado para las interfaces ITGF y la herramienta ASSIST
  -- Fecha: 30/04/2014
  -- Autor: Sergio Servín Arce
  ---------------------------------------------------------------------------
  -- Declaración de variables privadas
  V_NOM_ARCHIVO VARCHAR2(30);
  --V_SQL         VARCHAR2(3000);
  V_FEC_PROCESO DATE;
  V_REPROCESO   VARCHAR2(1) := 'N';

  -- FUNCIONES --

  -- Función que obtiene la fecha de proceso
  FUNCTION FU_OBT_FEC_PROCESO
  RETURN DATE
  IS
  BEGIN
    IF V_REPROCESO = 'S' THEN
      RETURN TO_DATE(fug_obt_pardinamico('FEC_PRO_ASSIST'),'DD/MM/YYYY');
    ELSE
      RETURN pag_cal.fu_obt_fec_actual(4);
    END IF;
  END;

  -- FunciÓn que obtiene el nombre del cliente
  FUNCTION FU_OBT_NOM_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                              P_TIPO IN VARCHAR2)
  RETURN VARCHAR2
  IS
     V_NOM_CLIENTE VARCHAR2(30);
  BEGIN
    V_NOM_CLIENTE := ' ';
    --
    IF P_TIPO = 'F' THEN  -- Primer nombre de la persona Física
      BEGIN
        SELECT NVL(TRIM(F.PRI_NOMBRE),'SIN NOMBRE')
         INTO V_NOM_CLIENTE
          FROM BA_PER_FISICAS F
        WHERE F.COD_PERSONA=P_COD_PERSONA;
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
  FUNCTION FU_OBT_APE_CLIENTE(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                              P_TIPO IN VARCHAR2)
  RETURN VARCHAR2
  IS
     V_APE_CLIENTE VARCHAR2(70);
  BEGIN
    V_APE_CLIENTE := NULL;
    --
    IF P_TIPO = 'F' THEN  -- Primer nombre de la persona Física
      BEGIN
        SELECT NVL(TRIM(F.PRI_APELLIDO||' '||F.SEG_APELLIDO),'SIN APELLIDO')
         INTO V_APE_CLIENTE
          FROM BA_PER_FISICAS F
        WHERE F.COD_PERSONA = P_COD_PERSONA;
        --
      EXCEPTION
        WHEN OTHERS THEN
          V_APE_CLIENTE := 'SIN APELLIDO';
      END;
    ELSIF P_TIPO = 'J' THEN -- Nombre comercial persona jurídica
     BEGIN
       SELECT NVL(TRIM(J.NOM_COMERCIAL),'S/D')
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
  RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE
  IS
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
  FUNCTION FU_OBT_DES_ACTIVIDAD(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_PERSONA VARCHAR2)
  RETURN BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE
  IS
    V_DES_ACTIVIDAD VARCHAR2(60);
  BEGIN
    IF P_TIP_PERSONA = 'F' THEN -- Persona Física
      BEGIN
         SELECT NVL(p.descripcion,' ')
           INTO V_DES_ACTIVIDAD
           FROM ba_per_fisicas f, ba_profesiones p
          WHERE f.cod_persona = p_cod_persona
            AND f.cod_profesion = p.cod_profesion;
      EXCEPTION
        WHEN OTHERS THEN
           return ' ';
      END;
    ELSE -- Persona Jurídica
      BEGIN
         SELECT a.descripcion
           INTO V_DES_ACTIVIDAD
           FROM ba_personas f, ge_actividades a
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
  FUNCTION FU_OBT_FEC_NACIMIENTO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_PERSONA VARCHAR2)
  RETURN VARCHAR2
  IS
    V_FEC_NACIMIENTO DATE;
  BEGIN
    IF P_TIP_PERSONA = 'F' THEN -- Persona Física
      BEGIN
         SELECT f.fec_nacimiento
           INTO V_FEC_NACIMIENTO
           FROM ba_per_fisicas f
          WHERE f.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
           return '01/01/1950';
      END;
    ELSE  -- Fecha apertura Persona Jurídica
      BEGIN
         SELECT j.fec_apertura
           INTO V_FEC_NACIMIENTO
           FROM ba_per_juridicas j
          WHERE j.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
           return '01/01/1950';
      END;
     END IF;
     --
   /*IF ( ( V_FEC_INGRESO < TO_DATE('01/01/1950','dd/mm/yyyy') ) OR
           ( TO_NUMBER(TO_CHAR(V_FEC_INGRESO,'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')))) THEN*/
     IF V_FEC_NACIMIENTO IS NOT NULL THEN
       IF ( V_FEC_NACIMIENTO < TO_DATE('01/01/1950','DD/MM/YYYY') ) OR
            (TO_NUMBER(TO_CHAR(V_FEC_NACIMIENTO,'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'))) THEN
          RETURN '01/01/1950';
       ELSE
         RETURN TO_CHAR(V_FEC_NACIMIENTO,'MM/DD/YYYY');
       END IF;
     ELSE
       RETURN '01/01/1950';
     END IF;
     --
  EXCEPTION
    WHEN OTHERS THEN
      Return NULL;
  END;

  -- Función que obtiene el código ISO del pais
  FUNCTION FU_OBT_COD_ISO_PAIS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                               P_TIP_BUSQUEDA VARCHAR2,
                               P_COD_PAIS BA_PAISES.COD_PAIS%TYPE)
  RETURN GE_AST_PAISES.COD_AST_PAIS%TYPE
  IS
    V_COD_ISO_PAIS GE_AST_PAISES.COD_AST_PAIS%TYPE;
  BEGIN
    IF P_COD_PERSONA IS NOT NULL THEN
      IF P_TIP_BUSQUEDA = 'N' THEN   -- Pais de Nacionalización
        BEGIN
          SELECT P.COD_AST_PAIS
            INTO V_COD_ISO_PAIS
            FROM BA_PERSONAS PE, GE_AST_PAISES P
           WHERE PE.COD_PERSONA = P_COD_PERSONA
             AND PE.COD_PAIS = P.COD_PAIS;
        EXCEPTION
          WHEN OTHERS THEN
            V_COD_ISO_PAIS := 'PRY';
        END;
      ELSE -- Pais de la Dirección
        BEGIN
          SELECT P.COD_AST_PAIS
            INTO V_COD_ISO_PAIS
            FROM BA_DIRECCIONES D, GE_AST_PAISES P
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
  FUNCTION FU_OBT_DIR_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    V_DIRECCION BA_DIRECCIONES.DIRECCION%TYPE;
  BEGIN
    SELECT DI.DIRECCION
     INTO V_DIRECCION
      FROM BA_DIRECCIONES DI
       WHERE DI.COD_PERSONA = P_COD_PERSONA
         AND DI.TIPO = 'P';
    --
    RETURN V_DIRECCION;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN ' ';
  END;
  -- Función que obtiene la descripción del departamento
  FUNCTION FU_OBT_DES_DEP_CIU_POS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE, P_TIP_BUSQUEDA VARCHAR2)
  RETURN VARCHAR2
  IS
    V_DES_DEP_CIU_POS VARCHAR2(50);
  BEGIN
    IF P_TIP_BUSQUEDA = 'D' THEN   -- DEPARTAMENTO
      BEGIN
         SELECT DE.COD_DEPARTAMENTO
           INTO V_DES_DEP_CIU_POS
           FROM BA_DIRECCIONES D, BA_CIUDADES C, BA_DEPARTAMENTOS DE
          WHERE D.COD_PERSONA = P_COD_PERSONA
            AND D.COD_PAIS = C.COD_PAIS
            AND D.COD_CIUDAD = C.COD_CIUDAD
            AND C.COD_DEPARTAMENTO = DE.COD_DEPARTAMENTO
            AND D.PRINCIPAL = 'S';
      EXCEPTION
        WHEN OTHERS THEN
           V_DES_DEP_CIU_POS := ' ';
      END;
    ELSIF P_TIP_BUSQUEDA = 'C' THEN -- CIUDAD
      BEGIN
         SELECT nvl(C.DESCRIPCION, ' ')
           INTO V_DES_DEP_CIU_POS
           FROM BA_DIRECCIONES D, BA_CIUDADES C
          WHERE D.COD_PERSONA = P_COD_PERSONA
            AND D.COD_PAIS = C.COD_PAIS
            AND D.COD_CIUDAD = C.COD_CIUDAD
            AND D.PRINCIPAL = 'S';
      EXCEPTION
        WHEN OTHERS THEN
           V_DES_DEP_CIU_POS := ' ';
      END;
    ELSE -- COD. POSTAL
      BEGIN
         SELECT NVL(D.COD_POSTAL,' ')
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
  FUNCTION FU_OBT_TEL_PRINCIPAL(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    V_TELEFONO BA_TELEFONOS.TELEFONO%TYPE;
  BEGIN
    SELECT TE.TELEFONO
     INTO V_TELEFONO
      FROM BA_TELEFONOS TE
       WHERE TE.COD_PERSONA = P_COD_PERSONA
         AND TE.TIPO = 'P'
         AND TE.TIP_LINEA = 'B'
         AND PRINCIPAL = 'S';
    --
    RETURN V_TELEFONO;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN ' ';
  END;

  -- Función que obtiene si está o no en la lista PEP
  FUNCTION FU_OBT_PEP(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN CR_INF_FONDOS.PEP%TYPE
  IS
    V_PEP CR_INF_FONDOS.PEP%TYPE;
  BEGIN
     SELECT DECODE(NVL(A.PEP,'N'), 'N', 'N', 'Y')
       INTO V_PEP
       FROM CR_INF_FONDOS A
      WHERE A.COD_PERSONA = P_COD_PERSONA;

     RETURN V_PEP;
  EXCEPTION
    WHEN OTHERS THEN
      Return 'N';
  END;

  -- Función que obtiene el código de Herencia
  FUNCTION FU_OBT_COD_HERENCIA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    V_COD_HERENCIA BA_PERSONAS.COD_PERSONA%TYPE;
  BEGIN
     SELECT DECODE(NVL(A.FON_HERENCIA,'N'), 'S', 6, ' ')
       INTO V_COD_HERENCIA
       FROM CR_INF_FONDOS A
      WHERE COD_PERSONA = P_COD_PERSONA;

     RETURN V_COD_HERENCIA;
  EXCEPTION
    WHEN OTHERS THEN
      Return ' ';
  END;

  -- Función que obtiene la región de la cuenta
  FUNCTION FU_OBT_REGION_CUENTA(P_COD_OFICINA IN GE_CLIENTES.COD_OFICINA%TYPE)
  RETURN VARCHAR2
  IS
    V_REGION_CUENTA BA_DEPARTAMENTOS.COD_DEPARTAMENTO%TYPE;
  BEGIN
    --
    SELECT CI.COD_DEPARTAMENTO
    INTO V_REGION_CUENTA
    FROM BA_OFICINAS OFI, BA_CIUDADES CI
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
  FUNCTION FU_OBT_FEC_ING_CLIENTE(P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE)
  RETURN DATE
  IS
     V_FEC_INGRESO DATE;
  BEGIN
    SELECT A.FEC_INGRESO
    INTO V_FEC_INGRESO
    FROM GE_CLIENTES A
    WHERE A.COD_PERSONA = P_COD_PERSONA;

    IF ( ( V_FEC_INGRESO < TO_DATE('01/01/1950','dd/mm/yyyy') ) OR
           ( TO_NUMBER(TO_CHAR(V_FEC_INGRESO,'YYYY')) > TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')))) THEN
      RETURN TO_DATE('01/01/2001','MM/DD/YYYY');
    ELSE
        RETURN V_FEC_INGRESO;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN TO_DATE('01/01/2001','MM/DD/YYYY');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al buscar fecha del cliente Nro:'||P_COD_PERSONA||SQLERRM);
  END;

  -- Función que obtiene la fecha cerrada o cancelada de la cuenta
  -- Valores para P_TIPO
  -- 1 - LOS PRÉSTAMOS LA FECHA DE VENCIMIENTO
  -- 2 - Cancelada
  FUNCTION FU_OBT_FEC_CANCELACION(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                  P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE,
                                  P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                  P_TIPO IN VARCHAR2)
  RETURN VARCHAR2
  IS
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
              RAISE_APPLICATION_ERROR(-20000,'Error al buscar la fecha de vencimiento del préstamo'||sqlerrm);
          END;
          RETURN TO_CHAR(V_FECHA,'MM/DD/YYYY');

        ELSE
            --RETORNA LA FECHA DE MADURACIÓN INGRESADA POR PARÁMETRO.
            RETURN TO_DATE(PAI_AST.FU_OBT_FEC_MADURACION,'DD/MM/YYYY');
        END IF;

      --
      WHEN P_TIPO = 2 THEN
        CASE
          WHEN P_COD_MODALIDAD = 31 THEN
            BEGIN
              SELECT A.FEC_CAM_ESTADO
              INTO V_FECHA
              FROM GE_CUENTAS A
              WHERE A.ESTADO IN ('C','P')
                AND A.NRO_CUENTA = P_NRO_CUENTA;
              --
              IF V_FECHA IS NOT NULL THEN
                RETURN TO_CHAR(V_FECHA,'MM/DD/YYYY');
              ELSE
                RETURN ' ';
              END IF;
              --
            EXCEPTION
              WHEN OTHERS THEN
                RETURN ' ';
            END;
            --
          WHEN P_COD_MODALIDAD IN (32,33,41,42,45,442,455) THEN
            BEGIN
              SELECT A.FEC_CAM_ESTADO
              INTO V_FECHA
              FROM GE_CUENTAS A
              WHERE A.ESTADO IN ('C')
                AND A.NRO_CUENTA = P_NRO_CUENTA;
              --
              IF V_FECHA IS NOT NULL THEN
                RETURN TO_CHAR(V_FECHA,'MM/DD/YYYY');
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
                    RAISE_APPLICATION_ERROR(-20000,'Error al buscar la fecha de Cancelación del préstamo: '||sqlerrm);
                END;
              --
              IF V_FECHA IS NOT NULL THEN
                RETURN TO_CHAR(V_FECHA,'MM/DD/YYYY');
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
      RAISE_APPLICATION_ERROR(-20000,'Error al buscar fecha del cliente Nro:'||P_NRO_CUENTA||SQLERRM);
  END;

  -- Función que recupera la fecha de implementación de ASSIST
  FUNCTION FU_OBT_FEC_IMP_ASSIST
  RETURN DATE
  IS
    l_fec_imp_assist varchar2(10);
  BEGIN
    l_fec_imp_assist := fug_obt_pardinamico('FEC_IMP_ASSIST');
    IF l_fec_imp_assist IS NULL THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al buscar la fecha de implementación ASSIST '||sqlerrm);
    ELSE
      RETURN TO_DATE(l_fec_imp_assist,'DD/MM/yyyy');
    END IF;
  END;

  -- Función que recupera la fecha de maduración (a partir de que fecha se tomaría para las alertas)
  FUNCTION FU_OBT_FEC_MADURACION
  RETURN VARCHAR2
  IS
    l_fec_maduracion varchar2(10);
  BEGIN
    l_fec_maduracion := fug_obt_pardinamico('FEC_MAD_ASSIST');
    IF l_fec_maduracion IS NULL THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al buscar la fecha de maduración para ASSIST '||sqlerrm);
    ELSE
      RETURN TO_CHAR(TO_DATE(l_fec_maduracion,'DD/MM/YYYY'),'MM/DD/YYYY');
    END IF;
  END;

  -- Función que recupera el código de proposito
  FUNCTION FU_OBT_COD_PRO_CUENTAS(P_PROPOSITO GE_PRO_CUENTAS.DESCRIPCION%TYPE)
  RETURN VARCHAR2
  IS
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
  FUNCTION FU_OBT_PRO_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    CURSOR C_PRO IS
      SELECT FON.COD_PERSONA, FON.PRO_INGRESOS, FON.PRO_AHORROS, FON.PRO_VEN_ALQ, FON.PRO_GAS_OPERATIVOS, FON.PRO_OTROS
       FROM CR_INF_FONDOS FON
        WHERE COD_PERSONA = P_COD_PERSONA;

    v_cod_proposito ge_pro_cuentas.cod_proposito%type;
  BEGIN
    v_cod_proposito := 0;
    --
    FOR F_PRO IN C_PRO
    LOOP
      IF F_PRO.PRO_INGRESOS = 'S' THEN
        RETURN PAI_AST.FU_OBT_COD_PRO_CUENTAS('INGRESOS');
      ELSE IF F_PRO.PRO_AHORROS = 'S' THEN
        RETURN PAI_AST.FU_OBT_COD_PRO_CUENTAS('AHORROS');
      ELSE IF F_PRO.PRO_VEN_ALQ = 'S' THEN
        RETURN PAI_AST.FU_OBT_COD_PRO_CUENTAS('VENTA/ALQUILERES');
      ELSE IF F_PRO.PRO_GAS_OPERATIVOS = 'S' THEN
        RETURN PAI_AST.FU_OBT_COD_PRO_CUENTAS('GASTOS OPERATIVOS');
      ELSE IF F_PRO.PRO_OTROS IS NOT NULL THEN
        RETURN PAI_AST.FU_OBT_COD_PRO_CUENTAS(UPPER(F_PRO.PRO_OTROS));
             END IF;
           END IF;
          END IF;
        END IF;
      END IF;
    END LOOP;

    RETURN v_cod_proposito;
  END;

  -- Función que recupera el tipo de objetivo de la cuenta
  FUNCTION FU_OBT_TIP_OBJ_CUENTA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
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
  FUNCTION FU_OBT_COD_FON_CUENTAS(P_FONDO GE_ORI_FONDOS.DESCRIPCION%TYPE)
  RETURN VARCHAR2
  IS
    v_cod_fon_cuenta ge_ori_fondos.cod_ori_fondo%type;
  BEGIN

    SELECT COD_ORI_FONDO
    INTO v_cod_fon_cuenta
    FROM GE_ORI_FONDOS
    WHERE DESCRIPCION = P_FONDO;

    RETURN v_cod_fon_cuenta;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '0';
  END;

  -- Función que recupera el fuente de fondos de la cuenta
  FUNCTION FU_OBT_FON_CUENTAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    CURSOR C_FON IS
      SELECT FON.COD_PERSONA, FON.FON_TRANSFERENCIAS, FON.FON_SALARIO, FON.FON_PRESTAMOS,
        FON.FON_VTA_ACTIVOS, FON.FON_REN_FINANCIERAS, FON.FON_HERENCIA, FON.FON_AHORRO,
        FON.FON_PROPIO, FON.FON_OTROS
      FROM CR_INF_FONDOS FON
        WHERE COD_PERSONA = P_COD_PERSONA;

    v_cod_fon_cuenta ge_ori_fondos.cod_ori_fondo%type;
  BEGIN
    v_cod_fon_cuenta := 0;
    --
    FOR F_FON IN C_FON
    LOOP
      CASE
        WHEN F_FON.FON_TRANSFERENCIAS = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('TRANSFERENCIA');
        WHEN F_FON.FON_SALARIO = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('SALARIO');
        WHEN F_FON.FON_PRESTAMOS = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('PRESTAMOS');
        WHEN F_FON.FON_VTA_ACTIVOS = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('VENTA DE ACTIVOS');
        WHEN F_FON.FON_REN_FINANCIERAS = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('RENOVACIONES FINANCIERAS');
        WHEN F_FON.FON_HERENCIA = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('HERENCIA');
        WHEN F_FON.FON_AHORRO = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('AHORRO');
        WHEN F_FON.FON_PROPIO = 'S' THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS('PROPIOS');
        WHEN F_FON.FON_OTROS IS NOT NULL THEN
          RETURN PAI_AST.FU_OBT_COD_FON_CUENTAS(UPPER(F_FON.FON_OTROS));
        ELSE
          RETURN 0;
      END CASE;

    END LOOP;

    RETURN v_cod_fon_cuenta;
  END;

  -- Función que retorna la descripción del banco
  FUNCTION FU_OBT_DES_BANCO(P_COD_BANCO LC_TRANSFERENCIAS.COD_BCO_CORRESPONSAL%TYPE,
                            P_SIGLA GE_BANCOS.SIGLA%TYPE)
  RETURN VARCHAR2
  IS
    V_DES_BANCO GE_BANCOS.DESCRIPCION%TYPE;
    V_SIGLA     VARCHAR2(8);
  BEGIN
    SELECT A.DESCRIPCION, SUBSTR(A.DESCRIPCION,1,8)
    INTO V_DES_BANCO, V_SIGLA
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
  RETURN VARCHAR2
  IS
    V_DES_BANCO GE_BANCOS.DESCRIPCION%TYPE;

  BEGIN
      BEGIN
        --primero buscamos en la tabla de bancos
        SELECT PAI_AST.FU_OBT_DES_BANCO(A.COD_BANCO,'N')
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
  FUNCTION FU_OBT_DAT_TRANSFERENCIA(P_NRO_OPERACION IN LC_TRANSFERENCIAS.NRO_OPERACION%TYPE,
                                    P_NRO_CTA_REFERENCIA IN LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE,
                                   -- P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                    P_DATO IN NUMBER,
                                    P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE ,
                                    P_TIPO_MOV VARCHAR2,
                                    P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                    P_COD_GRU_TRANSACCION GE_AST_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE,
                                    P_COD_BANCO GE_BANCOS.COD_BANCO%type,
                                    P_MONTO GE_MOVIMIENTOS.MONTO%TYPE)
  RETURN VARCHAR2
  IS
    V_NRO_CUENTA        LC_TRANSFERENCIAS.NRO_CTA_REFERENCIA%TYPE/* :=''*/;
    V_ORIGINADOR        LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/;
    V_BAN_ORIGINADOR    LC_TRANSFERENCIAS.NOM_BANCO%TYPE/* :=''*/;
    V_BAN_INTERMEDIARIO LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/;
    V_BAN_BENEFICIARIO  LC_TRANSFERENCIAS.NOM_BANCO%TYPE /*:=''*/;
    V_NOM_BENEFICIARIO  LC_TRANSFERENCIAS.NOM_BENEFICIARIO%TYPE /*:=''*/;
    V_COD_PAI_BANCO     GE_AST_PAISES.COD_AST_PAIS%TYPE;
    V_COD_PAI_DESTINO   GE_AST_PAISES.COD_AST_PAIS%TYPE;
    V_BAN_INTERMEDIARIO_CORTO VARCHAR2(8);
  BEGIN

  --para hacer más veloz se utilizaría el CASE
  CASE
      WHEN P_COD_GRU_TRANSACCION = 'TRASFI-E' THEN-- Transferencias emitidas

            BEGIN
            SELECT TRAN.NOM_SOLICITANTE, PAI_AST.FU_OBT_DES_BANCO(7,'N'),
              PAI_AST.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL,'N'),
              TRAN.NOM_BANCO, TRAN.NOM_BENEFICIARIO,
              PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1),--PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1),
              PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,COD_PAI_BANCO),
              PAI_AST.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL,'S')
            INTO V_ORIGINADOR, V_BAN_ORIGINADOR,
              V_BAN_INTERMEDIARIO, V_BAN_BENEFICIARIO, V_NOM_BENEFICIARIO,
              V_COD_PAI_BANCO, V_COD_PAI_DESTINO, V_BAN_INTERMEDIARIO_CORTO
            FROM LC_TRANSFERENCIAS TRAN
            WHERE TRAN.NRO_OPERACION = P_NRO_OPERACION;
              --AND TRAN.COD_TIP_REFERENCIA = 12;
              EXCEPTION
                when no_data_found then
                  V_ORIGINADOR         := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));--'N.A.';
                  V_BAN_ORIGINADOR    := PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.';
                  V_BAN_BENEFICIARIO  := 'N.A.';
                  V_NOM_BENEFICIARIO  := 'N.A.';
                  V_BAN_INTERMEDIARIO := 'N.A.';--PAI_AST.FU_OBT_DES_BANCO(7,'N');
                  V_COD_PAI_DESTINO   := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                  V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                  V_COD_PAI_BANCO     := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);

                WHEN OTHERS THEN
                  V_NOM_BENEFICIARIO :=  SQLERRM;
              END;

      WHEN  P_COD_GRU_TRANSACCION = 'TRASFI-I' THEN -- Transferencias recibidas

              BEGIN
              SELECT TRAN.NOM_SOLICITANTE V_ORIGINADOR, TRAN.NOM_BANCO V_BAN_ORIGINADOR,
                PAI_AST.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL,'N')V_BAN_INTERMEDIARIO,
                PAI_AST.FU_OBT_DES_BANCO(7,'N')V_BAN_BENEFICIARIO, TRAN.NOM_BENEFICIARIO V_NOM_BENEFICIARIO,
                PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,COD_PAI_BANCO)V_COD_PAI_BANCO,
                PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) V_COD_PAI_DESTINO,
                PAI_AST.FU_OBT_DES_BANCO(TRAN.COD_BCO_CORRESPONSAL,'S')V_BAN_INTERMEDIARIO_CORTO
              INTO V_ORIGINADOR, V_BAN_ORIGINADOR,
                    V_BAN_INTERMEDIARIO, V_BAN_BENEFICIARIO, V_NOM_BENEFICIARIO,
                    V_COD_PAI_BANCO, V_COD_PAI_DESTINO, V_BAN_INTERMEDIARIO_CORTO
              FROM LC_TRANSFERENCIAS TRAN
              WHERE TRAN.NRO_OPERACION = P_NRO_OPERACION;
                --AND TRAN.COD_TIP_REFERENCIA = '00';
                 --AND TRAN.NRO_CTA_REFERENCIA = P_NRO_CTA_REFERENCIA;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 V_ORIGINADOR         := 'N.A.';
                  V_BAN_ORIGINADOR    := 'N.A.';
                  V_BAN_BENEFICIARIO  := PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.';
                  V_NOM_BENEFICIARIO  := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));--'N.A.';
                  V_BAN_INTERMEDIARIO := 'N.A.';--PAI_AST.FU_OBT_DES_BANCO(7,'N');
                  V_COD_PAI_DESTINO   := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                  V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                  V_COD_PAI_BANCO     := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
             WHEN OTHERS THEN
               NULL;
            END;

      WHEN P_COD_GRU_TRANSACCION in('TRASFN-E','TRASFN-I') THEN --para los que son transferencia SNP

                 IF P_TIPO_MOV = 'C' THEN
                   BEGIN
                    --Para las transferencias de recepción--(ingreso)
                    Select NVL(GST.NOM_SOLICITANTE,'N.A.') V_ORIGINADOR,
                           PAI_AST.FU_OBT_DES_BAN_SNP(GST.NRO_CTA_PTE_SOLICITANTE)V_BAN_ORIGINADOR,
                           PAI_AST.FU_OBT_DES_BANCO(1,'N')V_BAN_INTERMEDIARIO,
                           PAI_AST.FU_OBT_DES_BANCO(7,'N')V_BAN_BENEFICIARIO,
                           NVL(GST.NOM_BENEFICIARIO,'N.A.') V_NOM_BENEFICIARIO,
                           PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1)V_COD_PAI_BANCO,
                           PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1)V_COD_PAI_DESTINO,
                           'BCP'V_BAN_INTERMEDIARIO_CORTO

                    INTO  V_ORIGINADOR, V_BAN_ORIGINADOR,
                          V_BAN_INTERMEDIARIO, V_BAN_BENEFICIARIO, V_NOM_BENEFICIARIO,
                          V_COD_PAI_BANCO, V_COD_PAI_DESTINO, V_BAN_INTERMEDIARIO_CORTO
                    from
                          ge_snp_transferencias GST
                    where GST.fecha = P_FECHA
                    and   GST.cod_usuario = P_USUARIO
                    and   GST.hora = P_HORA
                    and   GST.FEC_RECEPCION IS NOT NULL;--condición para los ingresos(recepción)
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                          V_ORIGINADOR:= 'N.A.';--'TRANSF. G.U.I.';
                          V_BAN_ORIGINADOR:= FU_OBT_NOM_BANCO_TRASFN(P_HORA,P_USUARIO,P_FECHA,P_NRO_CTA_REFERENCIA,
                                                       P_TIPO_MOV,P_MONTO);--'N.A.';--'TRANSF. G.U.I.';
                          V_BAN_INTERMEDIARIO := PAI_AST.FU_OBT_DES_BANCO(1,'N');
                          V_BAN_BENEFICIARIO:= PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.';--'TRANSF. G.U.I.';
                          V_NOM_BENEFICIARIO:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));--'N.A.';--'TRANSF. G.U.I.';
                          V_COD_PAI_BANCO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                          V_COD_PAI_DESTINO:=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                          V_BAN_INTERMEDIARIO_CORTO := 'BCP';
                    WHEN OTHERS THEN
                    V_ORIGINADOR := 'ERROR';
                   END;
                END IF;

               IF P_TIPO_MOV = 'D' THEN
                     BEGIN
                      --Para las transferencias de envio--(egreso)
                      Select NVL(GST.NOM_SOLICITANTE,'N.A.') V_ORIGINADOR,
                             PAI_AST.FU_OBT_DES_BANCO(7,'N')V_BAN_ORIGINADOR,
                             PAI_AST.FU_OBT_DES_BANCO(1,'N')V_BAN_INTERMEDIARIO,
                             PAI_AST.FU_OBT_DES_BAN_SNP(GST.NRO_CTA_PTE_BENEFICIARIO)V_BAN_BENEFICIARIO,
                             NVL(GST.NOM_BENEFICIARIO,'N.A.') V_NOM_BENEFICIARIO,
                             PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1)V_COD_PAI_BANCO,
                             PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1)V_COD_PAI_DESTINO,
                             'BCP'V_BAN_INTERMEDIARIO_CORTO

                      INTO  V_ORIGINADOR, V_BAN_ORIGINADOR,
                            V_BAN_INTERMEDIARIO, V_BAN_BENEFICIARIO, V_NOM_BENEFICIARIO,
                            V_COD_PAI_BANCO, V_COD_PAI_DESTINO, V_BAN_INTERMEDIARIO_CORTO
                      from
                            ge_snp_transferencias GST
                      where GST.fecha = P_FECHA
                      and   GST.cod_usuario = P_USUARIO
                      and   GST.hora = P_HORA
                      and   GST.FEC_RECEPCION IS NULL;--condición para los EGRESOS(envio)
                     EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        IF V_ORIGINADOR IS NULL  THEN
                           V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));--'N.A.';--'TRANSF. G.U.I.';
                           V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.';--'TRANSF. G.U.I.';
                           V_BAN_INTERMEDIARIO := PAI_AST.FU_OBT_DES_BANCO(1,'N');
                           V_BAN_BENEFICIARIO:= FU_OBT_NOM_BANCO_TRASFN(P_HORA,P_USUARIO,P_FECHA,P_NRO_CTA_REFERENCIA,
                                                       P_TIPO_MOV,P_MONTO);--'N.A.';--'TRANSF. G.U.I.';
                           V_NOM_BENEFICIARIO:= 'N.A.';--'TRANSF. G.U.I.';
                           V_COD_PAI_BANCO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                           V_COD_PAI_DESTINO:=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);
                           V_BAN_INTERMEDIARIO_CORTO := 'BCP';
                        END IF;

                      WHEN OTHERS THEN
                      V_ORIGINADOR := 'ERROR';
                     END;
               END IF;
      WHEN P_COD_GRU_TRANSACCION = 'CHEQ-I' AND P_TIPO_MOV = 'C' THEN
                 V_BAN_BENEFICIARIO := PAI_AST.FU_OBT_DES_BANCO(7,'N');--BBVAPY siempre
                V_NOM_BENEFICIARIO := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));
                V_COD_PAI_BANCO := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                V_COD_PAI_DESTINO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                V_BAN_INTERMEDIARIO := 'N.A.';
                V_ORIGINADOR := 'N.A.';
                /*¿Cargo otros Bancos (plaza Local)------------- transacción padre (352)

                 ¿Cargo otros Bancos (plaza Extranjera)-------- transacción padre (136) transacción Hijo (633)
                 ¿Cargo otros Bancos (plaza Extranjera)-------- transacción padre (560) transacción Hijo (560)

                 ¿Cargo nuestro Banco ------------------------- transacción padre (351) transacción Hijo (606)
                 ¿Cargo nuestro Banco ------------------------- transacción padre (394) */

                 IF P_COD_TRA_PADRE IN (352,395,372) /*AND P_COD_TRANSACCION = 607*/ THEN
                   V_BAN_ORIGINADOR := 'BANCO PLAZA LOCAL';
                 ELSIF (P_COD_TRA_PADRE = 136 AND P_COD_TRANSACCION = 633) OR
                       (P_COD_TRA_PADRE = 560 AND P_COD_TRANSACCION = 560)THEN
                   V_BAN_ORIGINADOR := 'BANCO PLAZA EXTRANJERA';
                 ELSIF (P_COD_TRA_PADRE IN (351,371) AND P_COD_TRANSACCION = 606) OR
                       (P_COD_TRA_PADRE = 394)THEN
                   V_BAN_ORIGINADOR := PAI_AST.FU_OBT_DES_BANCO(7,'N');--BBVAPY siempre
                 ELSE
                   V_BAN_ORIGINADOR := 'OTROS BANCOS';
                 END IF;
                 V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
      WHEN P_COD_GRU_TRANSACCION = 'CHEQ-E' AND P_TIPO_MOV = 'D' THEN
                      --en caso de no tener cod_banco se despliega banco BBVA y su principal de cta.
                  IF P_COD_BANCO IS NULL THEN
                    V_BAN_BENEFICIARIO := PAI_AST.FU_OBT_DES_BANCO(7,'N');
                  ELSE
                    V_BAN_BENEFICIARIO := PAI_AST.FU_OBT_DES_BANCO(P_COD_BANCO,'N');
                  END IF;

                    V_NOM_BENEFICIARIO := 'N.A.';

                    V_COD_PAI_BANCO := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                    V_COD_PAI_DESTINO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                    V_BAN_INTERMEDIARIO := 'N.A.';
                    V_ORIGINADOR := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));
                    V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                    V_BAN_ORIGINADOR := PAI_AST.FU_OBT_DES_BANCO(7,'N');--BBVAPY siempre
      WHEN  P_COD_GRU_TRANSACCION = 'ATM-E' THEN --EGRESO
                    V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P')) ;
                    V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');
                    V_BAN_INTERMEDIARIO:= 'N.A.' ;
                    V_BAN_BENEFICIARIO:= 'N.A.'  ;
                    V_NOM_BENEFICIARIO:=FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'))  ;
                    V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;
      WHEN P_COD_GRU_TRANSACCION = 'EFECT-E' THEN
                    V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P')) ;
                    V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');
                    V_BAN_INTERMEDIARIO:= 'N.A.' ;
                    V_BAN_BENEFICIARIO:= 'N.A.'  ;
                    V_NOM_BENEFICIARIO:='N.A.'  ;
                    V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;
      WHEN  P_COD_GRU_TRANSACCION = 'PRESTA-I' THEN
                    V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P')) ;
                    V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');
                    V_BAN_INTERMEDIARIO:= 'N.A.' ;
                    V_BAN_BENEFICIARIO:= PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.'  ;
                    V_NOM_BENEFICIARIO:=FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));--'N.A.'  ;
                    V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;

      WHEN   P_COD_GRU_TRANSACCION = 'OTROS-E' THEN
                    V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P')) ;
                    V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');--'N.A.';
                    V_BAN_INTERMEDIARIO:= 'N.A.' ;
                    V_BAN_BENEFICIARIO:= 'N.A.'  ;
                    V_NOM_BENEFICIARIO:='N.A.'  ;
                    V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;


      WHEN P_COD_GRU_TRANSACCION = 'TRNINT-E' THEN
                    V_ORIGINADOR:= FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P')) ;
                    V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');
                    V_BAN_INTERMEDIARIO:= 'N.A.' ;
                    V_BAN_BENEFICIARIO:= PAI_AST.FU_OBT_DES_BANCO(7,'N')  ;
                    V_NOM_BENEFICIARIO:=FU_OBT_NOM_PERSONA_TRNINT(P_HORA,P_USUARIO,P_FECHA,P_NRO_CTA_REFERENCIA,
                                                                  P_TIPO_MOV,P_MONTO,P_COD_TRA_PADRE,P_COD_TRANSACCION);--'N.A.'  ;
                    V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                    V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;


    WHEN  P_COD_GRU_TRANSACCION = 'TRNINT-I' THEN
                      V_ORIGINADOR:= FU_OBT_NOM_PERSONA_TRNINT(P_HORA,P_USUARIO,P_FECHA,P_NRO_CTA_REFERENCIA,
                                                               P_TIPO_MOV,P_MONTO,P_COD_TRA_PADRE,P_COD_TRANSACCION);--'N.A.'  ;
                      V_BAN_ORIGINADOR:= PAI_AST.FU_OBT_DES_BANCO(7,'N');
                      V_BAN_INTERMEDIARIO:= 'N.A.' ;
                      V_BAN_BENEFICIARIO:= PAI_AST.FU_OBT_DES_BANCO(7,'N')  ;
                      V_NOM_BENEFICIARIO:=FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));
                      V_COD_PAI_BANCO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                      V_COD_PAI_DESTINO:= PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1) ;
                      V_BAN_INTERMEDIARIO_CORTO:= 'N.A.' ;


      WHEN P_COD_GRU_TRANSACCION IN( 'EFECT-I','PRESTA-E','OTROS-I') THEN

                    IF P_TIPO_MOV = 'C' THEN--crédito a cuenta
                      V_BAN_BENEFICIARIO := PAI_AST.FU_OBT_DES_BANCO(7,'N');
                      V_NOM_BENEFICIARIO := FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(P_NRO_CTA_REFERENCIA,'P'));
                      V_COD_PAI_BANCO := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                      V_COD_PAI_DESTINO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                      V_BAN_INTERMEDIARIO := 'N.A.';
                      V_ORIGINADOR := 'N.A.';
                      V_BAN_INTERMEDIARIO_CORTO := 'N.A.';
                      V_BAN_ORIGINADOR := 'N.A.';--PAI_AST.FU_OBT_DES_BANCO(7,'N');
                    ELSE                    --débito a cuenta
                      V_BAN_BENEFICIARIO := 'N.A.';
                      V_BAN_ORIGINADOR := PAI_AST.FU_OBT_DES_BANCO(7,'N');
                      V_NOM_BENEFICIARIO := 'N.A.';
                      V_COD_PAI_BANCO := PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                      V_COD_PAI_DESTINO :=PAI_AST.FU_OBT_COD_ISO_PAIS(NULL,NULL,1);--Cod Paraguay
                      V_BAN_INTERMEDIARIO := 'N.A.';
                      V_ORIGINADOR := 'N.A.';
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
  FUNCTION FU_OBT_NUM_CANAL_TRANSACCION(P_COD_USUARIO BA_USUARIOS.COD_USUARIO%TYPE)
  RETURN NUMBER
  IS
  V_NRO_CANAL NUMBER(2);
  BEGIN
    --1-VENTANILLA
    --2-ATM
    --3-AUTOSERVICIO
    --4-SISTEMA

    IF substr(P_COD_USUARIO,1,3) = 'ATM' THEN
      RETURN 2;
    END IF;


    BEGIN
       select 1
       INTO V_NRO_CANAL
       FROM CJ_CAJAS T
       WHERE T.COD_USUARIO = P_COD_USUARIO
       AND   T.TIPO = 'H';--humano
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
         AND   T.TIPO = 'A';--atm
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
         AND   T.TIPO = 'S';--autoservicio
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
   FUNCTION FU_OBT_NOM_PERSONA_TRNINT(P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                      P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                      P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                      P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                      P_TIPO_MOV VARCHAR2,
                                      P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE,
                                      P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                      P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
  RETURN VARCHAR2
  IS
  V_NOMBRE BA_PERSONAS.NOM_COMPLETO%TYPE;
--  V_CONTROL VARCHAR2(2000);
  BEGIN

    IF V_REPROCESO = 'S' THEN
        IF P_TIPO_MOV = 'C' THEN
          --buscar el originador en caso de ser por HBANK
          IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO,1,3) = 'ATM')) THEN


            BEGIN
               Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
               INTO V_NOMBRE
               from gv_movimientos_ast t
               where t.FECHA       = P_FECHA
               and   t.HORA        = P_HORA
               and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
               and   T.COD_TIP_MOVIMIENTO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
               and   t.COD_USUARIO = P_USUARIO
               AND   T.MONTO = P_MONTO_TR
               AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                   AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                   AND   TR.COD_MODULO = T.COD_MODULO
                                                                   AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
             EXCEPTION
               WHEN NO_DATA_FOUND THEN
                 V_NOMBRE := 'N.A.';
               WHEN OTHERS THEN
                 V_NOMBRE := SQLERRM;
             END;



          ELSE

             --PARA BUSCAR EL ORIGINADOR DE PAGOS DE NÓMINA y otros (transferencias por ITGF
             IF P_COD_TRA_PADRE IN (303,309,346,329) AND P_COD_TRANSACCION = 602 THEN--329 cda
                BEGIN
                   Select DISTINCT FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
                   INTO V_NOMBRE
                   from gv_movimientos_ast t
                   where t.FECHA       = P_FECHA
                   and   t.HORA        = P_HORA
                   and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                   and   T.COD_TIP_MOVIMIENTO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
                   and   t.COD_USUARIO = P_USUARIO
                   --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                   --PARA PAGOS DE NÓMINA--------
                   and   t.COD_TRA_PADRE = P_COD_TRA_PADRE--303 --
                  -- and   t.COD_MOD_PADRE = 3   --
                  -- and   t.COD_MAD_PADRE = 31  --
                   and   t.COD_TRANSACCION = 503--P_COD_TRANSACCION--503
                   ------------------------------
                   AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                       AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                       AND   TR.COD_MODULO = T.COD_MODULO
                                                                       AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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
          IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO,1,3) = 'ATM')) THEN
            BEGIN
               Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
               INTO V_NOMBRE
               from gv_movimientos_ast t
               where t.FECHA       = P_FECHA
               and   t.HORA        = P_HORA
               and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (CRÉDITO)
               and   T.COD_TIP_MOVIMIENTO != P_TIPO_MOV--condición para encontrar el otro movimiento (CRÉDITO)
               and   t.COD_USUARIO = P_USUARIO
               AND   T.MONTO = P_MONTO_TR
               AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                   AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                   AND   TR.COD_MODULO = T.COD_MODULO
                                                                   AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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
             IF P_COD_TRA_PADRE IN (303,309,346,329) AND P_COD_TRANSACCION = 503 THEN
                BEGIN
                   Select DISTINCT DECODE(t.COD_MODALIDAD,'45',t.DENOMINACION,
                                          FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P')))
                   INTO V_NOMBRE
                   from gv_movimientos_ast t
                   where t.FECHA       = P_FECHA
                   and   t.HORA        = P_HORA
                   and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                   and   T.COD_TIP_MOVIMIENTO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
                   and   t.COD_USUARIO = P_USUARIO
                   --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                   --PARA PAGOS DE NÓMINA--------
                   and   t.COD_TRA_PADRE = P_COD_TRA_PADRE--303 --
                  -- and   t.COD_MOD_PADRE = 3   --
                  -- and   t.COD_MAD_PADRE = 31  --
                   and   t.COD_TRANSACCION = 602--P_COD_TRANSACCION--503
                   ------------------------------
                   AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                       AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                       AND   TR.COD_MODULO = T.COD_MODULO
                                                                       AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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

     ELSE--PARA LOS MOVIMIENTOS DEL DÍA.
       IF P_TIPO_MOV = 'C' THEN
          --buscar el originador en caso de ser por HBANK
          IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO,1,3) = 'ATM')) THEN


            BEGIN
               Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
               INTO V_NOMBRE
               from ge_movimientos t, GE_TRANSACCIONES TR
               where t.FECHA       = P_FECHA
               and   t.HORA        = P_HORA
               and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
               and   TR.TIPO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
               and   t.COD_USUARIO = P_USUARIO
               AND   T.MONTO = P_MONTO_TR

               AND T.COD_MODULO = TR.COD_MODULO
               AND T.COD_MODALIDAD = TR.COD_MODALIDAD
               AND T.COD_TRANSACCION = TR.COD_TRANSACCION
               AND T.COD_MODULO = TR.COD_MODULO
               AND T.COD_MODALIDAD = TR.COD_MODALIDAD
               AND T.COD_TRANSACCION = TR.COD_TRANSACCION
               --AH,CC y PR
               AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
               AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)))

               AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                   AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                   AND   TR.COD_MODULO = T.COD_MODULO
                                                                   AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
             EXCEPTION
               WHEN NO_DATA_FOUND THEN
                 V_NOMBRE := 'N.A.';
               WHEN OTHERS THEN
                 V_NOMBRE := SQLERRM;
             END;



          ELSE

             --PARA BUSCAR EL ORIGINADOR DE PAGOS DE NÓMINA y otros (transferencias por ITGF
             IF P_COD_TRA_PADRE IN (303,309,346,329) AND P_COD_TRANSACCION = 602 THEN--329 cda
                BEGIN
                   Select DISTINCT FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
                   INTO V_NOMBRE
                   from ge_movimientos t, GE_TRANSACCIONES TR
                   where t.FECHA       = P_FECHA
                   and   t.HORA        = P_HORA
                   and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                   and   TR.TIPO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
                   and   t.COD_USUARIO = P_USUARIO
                   --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                   --PARA PAGOS DE NÓMINA--------
                   and   t.COD_TRA_PADRE = P_COD_TRA_PADRE--303 --
                  -- and   t.COD_MOD_PADRE = 3   --
                  -- and   t.COD_MAD_PADRE = 31  --
                   and   t.COD_TRANSACCION = 503--P_COD_TRANSACCION--503
                   ------------------------------
                   AND T.COD_MODULO = TR.COD_MODULO
                   AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                   AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                   --AH,CC y PR
                   AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                   AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)))

                   AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                       AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                       AND   TR.COD_MODULO = T.COD_MODULO
                                                                       AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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
          IF ((P_USUARIO = 'HBANK') or (substr(P_USUARIO,1,3) = 'ATM')) THEN
            BEGIN
               Select FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P'))
               INTO V_NOMBRE
               from ge_movimientos t, GE_TRANSACCIONES TR
               where t.FECHA       = P_FECHA
               and   t.HORA        = P_HORA
               and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (CRÉDITO)
               and   TR.tipo != P_TIPO_MOV--condición para encontrar el otro movimiento (CRÉDITO)
               and   t.COD_USUARIO = P_USUARIO
               AND   T.MONTO = P_MONTO_TR
               AND T.COD_MODULO = TR.COD_MODULO
               AND T.COD_MODALIDAD = TR.COD_MODALIDAD
               AND T.COD_TRANSACCION = TR.COD_TRANSACCION
               --AH,CC y PR
               AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
               AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)))
               AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                   AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                   AND   TR.COD_MODULO = T.COD_MODULO
                                                                   AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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
             IF P_COD_TRA_PADRE IN (303,309,346,329) AND P_COD_TRANSACCION = 503 THEN
                BEGIN
                   Select DISTINCT DECODE(t.COD_MODALIDAD,'45',CU.DENOMINACION,
                                          FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P')))
                   INTO V_NOMBRE
                   from ge_movimientos t, GE_TRANSACCIONES TR,GE_CUENTAS CU
                   where t.FECHA       = P_FECHA
                   and   t.HORA        = P_HORA
                   and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
                   and   TR.tipo != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
                   and   t.COD_USUARIO = P_USUARIO
                   --AND   T.MONTO = P_MONTO_TR <-caso pago NÓMINA no se tiene montos iguales
                   --PARA PAGOS DE NÓMINA--------
                   and   t.COD_TRA_PADRE = P_COD_TRA_PADRE--303 --
                  -- and   t.COD_MOD_PADRE = 3   --
                  -- and   t.COD_MAD_PADRE = 31  --
                   and   t.COD_TRANSACCION = 602--P_COD_TRANSACCION--503
                   ------------------------------
                   AND t.NRO_CUENTA = CU.NRO_CUENTA
                   AND T.COD_MODULO = TR.COD_MODULO
                   AND T.COD_MODALIDAD = TR.COD_MODALIDAD
                   AND T.COD_TRANSACCION = TR.COD_TRANSACCION
                   --AH,CC y PR
                   AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
                   AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)))
                   AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                                       AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                                       AND   TR.COD_MODULO = T.COD_MODULO
                                                                       AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'));
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
  FUNCTION FU_OBT_IND_CHEQ_DEVUELTO(P_NRO_DOCUMENTO GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE,
                                    P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                    P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                    P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                    P_TIPO_MOV VARCHAR2,
                                    P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE)
  RETURN VARCHAR2
  IS
  V_IND VARCHAR2(2):= '';

  BEGIN


  IF V_REPROCESO = 'S' THEN
      --busca el movimiento de devolución de acuerdo al nro de documento
      BEGIN
          Select 'S'
          INTO V_IND
          from GV_MOVIMIENTOS_AST t
          where T.FECHA  =  P_FECHA
          --AND   T.HORA = '18:44:12'
          and t.NRO_CUENTA = P_NRO_CTA_CLIENTE
          and t.NRO_DOCUMENTO = P_NRO_DOCUMENTO--<--
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
          from GE_MOVIMIENTOS t, GE_TRANSACCIONES TR
          where T.FECHA  =  P_FECHA
          --AND   T.HORA = '18:44:12'
          and t.NRO_CUENTA = P_NRO_CTA_CLIENTE
          and t.NRO_DOCUMENTO = P_NRO_DOCUMENTO--<--
          AND T.COD_USUARIO = P_USUARIO
          AND TR.TIPO != P_TIPO_MOV
          and t.monto = P_MONTO_TR

          AND T.COD_MODULO = TR.COD_MODULO
          AND T.COD_MODALIDAD = TR.COD_MODALIDAD
          AND T.COD_TRANSACCION = TR.COD_TRANSACCION
          --AH,CC y PR
          AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
          AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)));
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          V_IND := 'N';
        WHEN OTHERS THEN
          V_IND := 'N';
      END;
  END IF;

      RETURN V_IND ;
  END;
  --Función que retorna el BANCO BENEFICIARIO/ORIGINADOR en trasnacciones Nacionales(TRASFN-I/E) assist
  FUNCTION FU_OBT_NOM_BANCO_TRASFN(P_HORA GE_MOVIMIENTOS.HORA%TYPE,
                                      P_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE,
                                      P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
                                      P_NRO_CTA_CLIENTE GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                      P_TIPO_MOV VARCHAR2,
                                      P_MONTO_TR GE_MOVIMIENTOS.MONTO%TYPE)
                                     -- P_COD_TRA_PADRE GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                      --P_COD_TRANSACCION GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
  RETURN VARCHAR2
  IS
  V_NOMBRE BA_PERSONAS.NOM_COMPLETO%TYPE;
 -- V_CONTROL VARCHAR2(2000);
  BEGIN

    IF V_REPROCESO = 'S' THEN
        BEGIN
           Select DISTINCT DECODE (T.COD_MODALIDAD,'455',T.DENOMINACION , FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P')))
           INTO V_NOMBRE
           from gv_movimientos_ast t
           where t.FECHA       = P_FECHA
           and   t.HORA        = P_HORA
           and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
           and   T.COD_TIP_MOVIMIENTO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
           and   t.COD_USUARIO = P_USUARIO
           AND   T.MONTO = P_MONTO_TR/*
           AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                               AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                               AND   TR.COD_MODULO = T.COD_MODULO
                                                               AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'))*/;
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
             V_NOMBRE := 'N.A.';
           WHEN OTHERS THEN
             V_NOMBRE := SQLERRM;
         END;
    ELSE--MOVIMIENTO DEL DÍA.
         BEGIN
           Select DISTINCT DECODE (T.COD_MODALIDAD,'455',CU.DENOMINACION , FUE_OBT_NOM_PERSONA(FUG_OBT_CLI_PRINCIPAL(T.NRO_CUENTA,'P')))
           INTO V_NOMBRE
           from ge_movimientos t, GE_TRANSACCIONES TR,GE_CUENTAS CU
           where t.FECHA       = P_FECHA
           and   t.HORA        = P_HORA
           and   t.NRO_CUENTA != P_NRO_CTA_CLIENTE --condición para encontrar el otro movimiento (DEBITO)
           and   TR.TIPO != P_TIPO_MOV--condición para encontrar el otro movimiento (DEBITO)
           and   t.COD_USUARIO = P_USUARIO
           AND   T.MONTO = P_MONTO_TR

           AND t.NRO_CUENTA = CU.NRO_CUENTA
           AND T.COD_MODULO = TR.COD_MODULO
           AND T.COD_MODALIDAD = TR.COD_MODALIDAD
           AND T.COD_TRANSACCION = TR.COD_TRANSACCION
           --AH,CC y PR
           AND (TR.cod_transaccion > 0 OR T.cod_rubro IS NOT NULL)
           AND (TR.cod_modulo in( 3,4,6) OR (TR.cod_modulo = 9 AND T.cod_mod_padre in( 3,4,6)))
           /*
           AND   EXISTS (SELECT 1 FROM GE_AST_TRANSACCIONES TR WHERE TR.COD_TRA_PADRE = T.COD_TRA_PADRE
                                                               AND   TR.COD_MODALIDAD = T.COD_MODALIDAD
                                                               AND   TR.COD_MODULO = T.COD_MODULO
                                                               AND   TR.COD_GRU_TRANSACCION IN ('TRNINT-I','TRNINT-E'))*/;
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
  FUNCTION FU_VER_FEC_PROCESO(P_FECHA DATE)
  RETURN BOOLEAN
  IS
    V_EXISTE NUMBER;
  BEGIN
    --
    SELECT DISTINCT 1
    INTO V_EXISTE
    FROM GE_CTA_IMP_ASSIST A
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
      RAISE_APPLICATION_ERROR(-20000,'Error al verificar la fecha de proceso.'||sqlerrm);
  END;

  -- Verifica si el cliente es principal de alguna cuenta
  FUNCTION FU_VER_CLI_PRINCIPAL(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE)
  RETURN VARCHAR2
  IS
    V_PRINCIPAL VARCHAR2(1);
  BEGIN
    --
    BEGIN
      SELECT DISTINCT 'S'
      INTO V_PRINCIPAL
      FROM GE_CTA_CLIENTES A, GE_CTA_IMP_ASSIST B
      WHERE A.NRO_CUENTA = B.NRO_CUENTA
        AND A.COD_PERSONA = B.COD_PERSONA
        AND A.COD_PERSONA = P_COD_PERSONA
        AND A.RELACION = 'P'
        AND A.COD_MODULO IN (3,4,6);

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

  -- PROCEDURES --

  -- Procedimiento que genera archivo TXT para ASSIST.
  PROCEDURE PR_GEN_ARCHIVO_AST(P_NOM_ARCHIVO IN VARCHAR2,
                               --P_SQL IN VARCHAR2,
                               --P_CON_CABECERA IN VARCHAR2,
                               --P_SEPARADOR IN VARCHAR2,
                               P_AGREGA IN VARCHAR2)
  IS
    --
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    --
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    --V_COLUMNAS     NUMBER(2)      := 2;    -- Cantidad de columnas a leer
    --V_ENCABEZADO   VARCHAR2(400)  := '';   -- Contendrá encabezado?
    --V_RESULT       BOOLEAN;
    --V_CURSOR       NUMBER;
    --V_COL_VARCHAR2 VARCHAR2(2000);
    --V_ROWS         NUMBER(10)     := 1;
    --V_FILAS        NUMBER(9)      := 0;     -- contendra el valor del campo
    --V_RESULTADO    VARCHAR2(5000) := '';
    --V_VAL_CAMPO    VARCHAR(2000);
    --V_FEC_PROCESO VARCHAR(10) := TO_CHAR(PAI_AST.FU_OBT_FEC_PROCESO,'DD/MM/YYYY');
    --V_FEC_PROCESO_DAT date := PAI_AST.FU_OBT_FEC_PROCESO;

    CURSOR C_GRUPO_TRANSACCIONES IS
        -- ARCHIVO DE GRUPO DE TRANSACCIONES
        -- NOMBRE DEL ARCHIVO: TG20131231.TXT
        SELECT LPAD(COD_GRU_TRANSACCION,8,' ')||
        LPAD(DESCRIPCION,100,' ')CADENA
        FROM GE_GRU_TRA_ASSIST
        WHERE FEC_ENVIO IS NULL
          OR TRUNC(FEC_INSERCION) <= TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
          OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO);


    CURSOR C_COD_TRANSACCIONES IS
    -- ARCHIVOS TRANSACCIONES
    -- NOMBRE DEL ARCHIVO: CT20131231.TXT
    SELECT LPAD(COD_AST_TRANSACCION,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||
      DECODE(TIPO,'C','I','D','O')||DECODE(IND_MONITOREO,'N','N','S','Y')||
      LPAD(COD_GRU_TRANSACCION,8,' ') CADENA
    FROM GE_AST_TRANSACCIONES
    WHERE /*( COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR COD_MODULO = 6)
      AND */( FEC_ENVIO IS NULL
            OR TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
            OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO );


    CURSOR C_PAISES IS
    -- ARCHIVOS DE PAISES
    -- NOMBRE DEL ARCHIVO: PA20131231.TXT
    SELECT LPAD(COD_AST_PAIS,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||
      LPAD(COD_RIE_PAIS,3,' ')||'  '||
      LPAD(DECODE(COD_RIE_INT_PAIS,NULL,COD_RIE_PAIS,COD_RIE_INT_PAIS),3,' ')||'  ' CADENA
    FROM GE_AST_PAISES
    WHERE FEC_ENVIO IS NULL
      OR TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;


    CURSOR C_DEPARTAMENTOS IS
    -- ARCHIVO DE ESTADOS (DEPARTAMENTOS)
    -- NOMBRE DEL ARCHIVO: ES20131231.TXT
    SELECT LPAD(COD_DEPARTAMENTO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||' '||LPAD('PRY',8,' ') CADENA
    FROM BA_DEPARTAMENTOS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
----------

    CURSOR C_REGIONES IS
    -- ARCHIVO DE REGIONES (DEPARTAMENTOS)
    -- NOMBRE DEL ARCHIVO: RE20131231.TXT
    SELECT LPAD(COD_DEPARTAMENTO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_DEPARTAMENTOS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
     OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
 ---------------
    CURSOR C_SUCURSALES IS
    -- ARCHIVO DE SUCURSALES
    -- NOMBRE DEL ARCHIVO: SU20131231.TXT
    SELECT LPAD(COD_OFICINA,10,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_OFICINAS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
-------------
    CURSOR C_MONEDAS IS
    -- ARCHIVO DE MONEDAS
    -- NOMBRE DEL ARCHIVO: MO20131231.TXT
    SELECT LPAD(COD_MONEDA,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_MONEDAS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
-------------
    CURSOR C_OFICIALES IS
    -- ARCHIVO DE OFICIALES
    -- NOMBRE DEL ARCHIVO: FU20131231.TXT
    SELECT LPAD(COD_USUARIO,20,' ')||LPAD(SUBSTR(NOMBRE,1,80),80,' ')||TO_CHAR(FEC_INGRESO,'MM/DD/YYYY')CADENA
    FROM BA_USUARIOS
    WHERE ( NVL(OFICIAL,'N') = 'S'
      AND ( TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO ) )
      OR (COD_USUARIO IN ('PY00763','PY00107','PY00365',
      'PY00403','PY00108','PY00171','PY00441','PY00146','PY00027',
      'PY00500','PY00137','PY00329','XPY9212','PY00258','BBVA','MIGRA')
      AND ( TRUNC(FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO )
      OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO) ) );
------------------------
    CURSOR C_TIPO_CUENTAS IS
    -- ARCHIVO DE TIPO DE CUENTAS
    -- NOMBRE DEL ARCHIVO: TC20131231.TXT
    SELECT LPAD(COD_MODALIDAD,8,' ')||LPAD(replace((SUBSTR(DESCRIPCION,1,40)),chr(10),''),40,' ') CADENA
    FROM GE_MODALIDADES
    WHERE ( COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR COD_MODULO = 6 )
      AND TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
-------------------
    CURSOR C_PROPOSITO_CUENTA IS
    -- ARCHIVO DE PROPOSITO DE LA CUENTA
    -- NOMBRE DEL ARCHIVO: CP20131231.TXT
    SELECT LPAD(COD_PROPOSITO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM GE_PRO_CUENTAS WHERE DESCRIPCION IS NOT NULL
      AND TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
-------------------
    CURSOR C_OBJETIVO_CUENTA IS
    -- ARCHIVO DE OBJETIVO DE LA CUENTA
    -- NOMBRE DEL ARCHIVO: OC20131231.TXT
    SELECT LPAD(VAL_MINIMO,8,' ')||LPAD(SUBSTR(UPPER(SIGNIFICADO),1,40),40,' ') CADENA
    FROM BA_COD_REFERENCIAS
    WHERE DOMINIO = 'DTM_RIESGO'
      AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO);

---------------------
    CURSOR C_ORIGEN_FONDO IS
    -- ARCHIVO DE ORIGEN DE FONDOS
    -- NOMBRE DEL ARCHIVO: OF20131231.TXT
    SELECT LPAD(COD_ORI_FONDO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM GE_ORI_FONDOS WHERE DESCRIPCION IS NOT NULL
      AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO);

    CURSOR C_TIPO_RELACION IS
    -- ARCHIVO DE TIPO DE RELACION
    -- NOMBRE DEL ARCHIVO: CR20131231.TXT
      SELECT LPAD(SUBSTR(VAL_MINIMO,1,8),8,' ')||LPAD(SUBSTR(SIGNIFICADO,1,30),30,' ')||LPAD(SUBSTR(VAL_MAXIMO,1,8),8,' ') CADENA
      FROM BA_COD_REFERENCIAS WHERE DOMINIO = 'AST_RELACION';
        /*AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
        OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO);*/
-------------------
    CURSOR C_CLIENTES IS
            SELECT DISTINCT  replace(( RPAD(CTACLI.COD_PERSONA,20,' ')||                               /*(1)Número de Cliente*/ /*Layouts_Assist_Clientes_V3.0.0.doc*/
               RPAD(DECODE(PER.TIPO,'F','FISICA','J','JURIDICA'),8,' ')||               /*(2)Tipo de Cliente*/
               RPAD(PAI_AST.FU_OBT_NOM_CLIENTE(CTACLI.COD_PERSONA, PER.TIPO),80,' ')||  /*(3)Primer Nombre del Cliente*/
               RPAD(PAI_AST.FU_OBT_APE_CLIENTE(CTACLI.COD_PERSONA, PER.TIPO),80,' ')||  /*(4)Apellidos del Cliente/Nombre del Negocio*/
               'N'||                                                                    /*(5)Grupo Económico (grupo de empresas)*/
               LPAD(PER.NRO_DOCUMENTO,30,' ')||                                         /*(6)Número de Identificación de Documento*/
               LPAD(PAI_AST.FU_OBT_DES_TIP_DOC(PER.COD_TIP_DOCUMENTO),50,' ')||         /*(7)Tipo de Documento de Identificación*/
               LPAD(UPPER(PAI_AST.FU_OBT_DES_ACTIVIDAD(CTACLI.COD_PERSONA, PER.TIPO)),50,' ')||/*(8)Ocupación*/
               LPAD(PAI_AST.FU_OBT_FEC_NACIMIENTO(CTACLI.COD_PERSONA, PER.TIPO),10,' ')||  /*(9)Fecha de Nacimiento*/
               RPAD(PAI_AST.FU_OBT_COD_ISO_PAIS(CTACLI.COD_PERSONA, 'N',NULL),8,' ')||     /*(10)País de Nacionalidad*/
               RPAD(PAI_AST.FU_OBT_COD_ISO_PAIS(CTACLI.COD_PERSONA, 'D',NULL),8,' ')||     /*(11)País de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DIR_PRINCIPAL(CTACLI.COD_PERSONA),120,' ')||            /*(12)Campo para Dirección 1*/
               LPAD(' ',120,' ')||                                                         /*(13)Campo para Dirección 2*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'C'),50,' ')||      /*(14)Ciudad de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'D'),8,' ')||       /*(15)Estado de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'P'),10,' ')||      /*(16)Código Postal del Domicilio*/
               LPAD(PAI_AST.FU_OBT_TEL_PRINCIPAL(CTACLI.COD_PERSONA),20,' ')||             /*(17)Número de Teléfono 1*/
               LPAD(' ',20,' ')||                                                          /*(18)Número de Teléfono 2*/
               LPAD(NVL(PER.DIR_CORREO,' '),50,' ')||                                      /*(19)Email*/
               PAI_AST.FU_OBT_PEP(CTACLI.COD_PERSONA)||                                    /*(20)Persona Políticamente Expuesta*/
               LPAD(decode((FUE_OBT_ARL_CLI(CTACLI.COD_PERSONA)),'BAJO',1,'MEDIO',2,'ALTO',3,0),4,' ')|| /*(21)Código de Riesgo*/
                                                                                           /*(22)Fuente de Patrimonio (riqueza)*/
               RPAD(PAI_AST.FU_OBT_TIP_OBJ_CUENTA(CTACLI.COD_PERSONA),8,' ')||             /*(23)Tipo del Objetivo*/
               LPAD(TO_CHAR(PAI_AST.FU_OBT_FEC_ING_CLIENTE(CTACLI.COD_PERSONA),'MM/DD/YYYY'),10,' ') ),chr(10), ' ') CADENA/*(24)Fecha de Comienzo (fecha de captación)*/
                                                                                      /*(25)Fecha de Terminación       */
               FROM GE_CTA_CLIENTES CTACLI, GE_CLIENTES CLI, BA_PERSONAS PER
               WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
                 AND CTACLI.COD_PERSONA = PER.COD_PERSONA
                 AND ( TRUNC(CLI.FEC_INSERCION) <= TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                        OR TRUNC(CLI.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                     )
                 AND EXISTS ( SELECT 1
                              FROM GE_CTA_IMP_ASSIST X
                              WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                                AND X.COD_PERSONA = CTACLI.COD_PERSONA
                             );



    CURSOR C_CUENTAS IS

      -- ARCHIVO DE CUENTAS
      -- NOMBRE DEL ARCHIVO: CU20131231.TXT
      SELECT LPAD(CTACLI.NRO_CUENTA,20,' ')||
             LPAD(CTACLI.COD_PERSONA,20,' ')||
             LPAD(

               REPLACE (CTA.DENOMINACION,CHR(10),' ')

             ,80,' ')||
             LPAD(FUG_OBT_OFI_OFICIAL(CTACLI.COD_PERSONA),10,' ')||
             LPAD(CTA.COD_MONEDA,8,' ')||
             LPAD(CLI.COD_USU_OFICIAL,20,' ')||
             LPAD('PRY',8,' ')||
             LPAD(PAI_AST.FU_OBT_REGION_CUENTA(CLI.COD_OFICINA),8,' ')||
             LPAD(TO_CHAR(CTA.FEC_APERTURA,'MM/DD/YYYY'),10,' ')||
             LPAD(PAI_AST.FU_OBT_FEC_CANCELACION(CTACLI.NRO_CUENTA, CTACLI.COD_MODULO, CTACLI.COD_MODALIDAD,'2'),10,' ')||
             --LPAD(PAI_AST.FU_OBT_FEC_MADURACION,10,' ')||--FECHA DE VENCIMIENTO
             LPAD(PAI_AST.FU_OBT_FEC_CANCELACION(CTACLI.NRO_CUENTA, CTACLI.COD_MODULO, CTACLI.COD_MODALIDAD,'1'),10,' ')||--FECHA DE VENCIMIENTO
             LPAD(' ',3,' ')||
             LPAD(' ',1,' ')||
             LPAD(' ',20,' ')||
             LPAD(CTA.COD_MODALIDAD,8,' ')||
             LPAD(' ',8,' ')||
             LPAD(DECODE(PAI_AST.FU_OBT_PRO_CUENTAS(CTACLI.COD_PERSONA),'0',' ',PAI_AST.FU_OBT_PRO_CUENTAS(CTACLI.COD_PERSONA)),8,' ')||
             LPAD(PAI_AST.FU_OBT_TIP_OBJ_CUENTA(CTACLI.COD_PERSONA),8,' ')||
             LPAD(DECODE(PAI_AST.FU_OBT_FON_CUENTAS(CTACLI.COD_PERSONA),'0',' ',PAI_AST.FU_OBT_FON_CUENTAS(CTACLI.COD_PERSONA)),8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',20,' ')||
             LPAD('PRY',8,' ')||
             LPAD(DECODE(FUG_OBT_SIT_CUENTA(CTACLI.NRO_CUENTA),'N','Y','N'),1,' ')||
             '  '||
             LPAD('PRY',8,' ') CADENA
         FROM GE_CTA_CLIENTES CTACLI, GE_CUENTAS CTA, GE_CLIENTES CLI
          WHERE CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
            AND CTACLI.COD_PERSONA = CLI.COD_PERSONA
            AND CTACLI.RELACION = 'P'
            AND (TRUNC(CLI.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
                    OR TRUNC(CLI.FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO
                   )
                   and  CTACLI.cod_persona = 399531
            AND EXISTS ( SELECT 1 FROM GE_CTA_IMP_ASSIST X
                         WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                           AND X.COD_PERSONA = CTACLI.COD_PERSONA
                        );
-----------------
    CURSOR C_RELACIONES IS
    -- ARCHIVO DE RELACIONES CON CUENTAS
    -- NOMBRE DEL ARCHIVO: RC20131231.TXT
    SELECT RPAD(CTACLI.COD_PERSONA,20,' ')||RPAD(CTACLI.NRO_CUENTA,20,' ')||RPAD(CTACLI.RELACION,8,' ')||'I' CADENA
    FROM GE_CTA_CLIENTES CTACLI
    WHERE ( CTACLI.COD_MODALIDAD IN (31,32,33,41,42,45,442) OR CTACLI.COD_MODULO = 6 )
      AND CTACLI.RELACION != 'P'
      AND (TRUNC(CTACLI.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(CTACLI.FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO )
      AND EXISTS ( SELECT 1
                   FROM GE_CTA_IMP_ASSIST X
                   WHERE TRIM(X.NRO_CUENTA) = CTACLI.NRO_CUENTA
                      AND TRIM(X.COD_PERSONA) = CTACLI.COD_PERSONA )
    ORDER BY CTACLI.NRO_CUENTA;

 ------------

   /* CURSOR C_PERFILES IS
    -- ARCHIVO DE PERFILES
    -- NOMBRE DEL ARCHIVO: PL20131231.TXT
    SELECT ACT.COD_PERSONA,
      'INC' TIPO,
      RPAD(ACT.COD_PERSONA,20,' ')||
      'A'||
      RPAD('INC',8,' ')||
      ' 1'||
      '12'||
      LPAD(CAN_TRA_CREDITO,10,' ')||
      --LPAD(TO_CHAR(ROUND(ACT.MTO_PRO_CREDITO/G.VAL_CONVERSION,2),'99999999999999.99'),20,' ')||
      LPAD(FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA),20,' ')||
      '  1' CADENA
    FROM CR_ACT_ESPERADAS ACT, GE_COTIZACIONES G
    WHERE ACT.FECHA = G.FECHA
      AND G.COD_MONEDA = 'USD'
      --AND ROUND(ACT.MTO_PRO_CREDITO/G.VAL_CONVERSION) > 0
      AND FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) > 1
      AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
      AND ACT.FECHA = ( SELECT MAX(FECHA)
                                       FROM CR_ACT_ESPERADAS
                                       WHERE COD_PERSONA = ACT.COD_PERSONA
                                      )
      AND (TRUNC(ACT.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
            OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
           )
      AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                   WHERE X.COD_PERSONA = ACT.COD_PERSONA
                 )
    UNION ALL
      SELECT ACT.COD_PERSONA,
             'OUT',
             RPAD(ACT.COD_PERSONA,20,' ')||
             'A'||
             RPAD('OUT',8,' ')||
             ' 1'||
             '12'||
             LPAD(CAN_TRA_DEBITO,10,' ')||
             --LPAD(TO_CHAR(ROUND(ACT.MTO_PRO_DEBITO/G.VAL_CONVERSION,2),'99999999999999.99'),20,' ')||
             LPAD(FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_DEBITO, NULL, ACT.FECHA),20,' ')||
             '  1' CADENA
        FROM CR_ACT_ESPERADAS ACT, GE_COTIZACIONES G
         WHERE ACT.FECHA = G.FECHA
            AND G.COD_MONEDA = 'USD'
            --AND ROUND(ACT.MTO_PRO_DEBITO/G.VAL_CONVERSION)  > 0
            AND FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) > 1 -- SE USA EL CAMPO MTO_PRO_CREDITO PARA QUE ENTRE SU PAR, POR MAS QUE SEA MENOR A 1 USD
            AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
            AND ACT.FECHA = ( SELECT MAX(FECHA)
                                       FROM CR_ACT_ESPERADAS
                                       WHERE COD_PERSONA = ACT.COD_PERSONA
                                      )
            AND (TRUNC(ACT.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
                  OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                  )
            AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                        WHERE X.COD_PERSONA = ACT.COD_PERSONA
                        )
    ORDER BY 1,2;*/


    CURSOR C_TRANSACCIONES IS

      SELECT LPAD(
      DECODE(MOVI.COD_GRU_TRANSACCION,'TRASFI-I',
                                      DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                       '372',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                       MOVI.COD_AST_TRANSACCION),
                                       MOVI.COD_AST_TRANSACCION)
      ,8,' ')||
        LPAD(MOVI.MONTO,20,' ')||
        LPAD(MOVI.FEC_VALOR,10,' ')||
        LPAD(MOVI.NRO_CUENTA,20,' ')||
        LPAD(MOVI.CONCEPTO,40,' ')||
        LPAD(MOVI.MONTO_ORIGINAL,20,' ')||
        LPAD(MOVI.COD_MONEDA,8,' ')||
        LPAD(PAI_AST.FU_OBT_NUM_CANAL_TRANSACCION(MOVI.CAJERO),4,' ')||
        LPAD(MOVI.HORA,8,' ')||
        LPAD(replace(MOVI.ORIGINADOR,chr(10), ' '),140,' ')||--para quitar los ENTERs
        LPAD(MOVI.BANCO_EMISOR,40,' ')||
        LPAD(MOVI.BANCO_INTERMEDIARIO,40,' ')||
        LPAD(MOVI.BANCO_BENEFICIARIO,40,' ')||
        LPAD(TRIM(replace(replace(MOVI.BENEFICIARIO, chr(10), ' '), chr(13), ' ')), 140, ' ') ||
        LPAD(MOVI.COD_PAI_BANCO_EMISOR,10,' ')||
        LPAD(' ',40,' ')||
        LPAD(MOVI.COD_PAI_BANCO_BENEFIARIO,8,' ')||
        LPAD(REPLACE(TRIM(REPLACE(REPLACE(MOVI.DET_TRANSACCION,CHR(10),' '),CHR(13),' ')), chr(124), '°'), 500) || --REEMPLAZAMOS LOS | POR ° PARA no generar error al importar al assist
        LPAD(MOVI.FEC_VALOR2,10,' ')||
        LPAD(MOVI.BAN_INTERMEDIARIO_CORTO,8,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',1,' ')||
        LPAD(MOVI.COD_OFICINA,10,' ')||
        LPAD(MOVI.CAJERO,20,' ')||
        LPAD(MOVI.HORA2,11,' ')||
        LPAD(' ',38,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',6,' ') CADENA
      FROM (SELECT ATR.COD_AST_TRANSACCION COD_AST_TRANSACCION,
              FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_AST.FU_OBT_FEC_PROCESO) MONTO,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR,
              MOV.NRO_CUENTA NRO_CUENTA,
              SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
              MOV.MONTO MONTO_ORIGINAL,
              MOV.COD_MONEDA COD_MONEDA,
              MOV.COD_MODALIDAD COD_MODALIDAD,
              MOV.HORA HORA,
              ATR.COD_GRU_TRANSACCION,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,2,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') ORIGINADOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,3,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,4,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_INTERMEDIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,5,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,6,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,7,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,8,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_BENEFIARIO,
              NVL(MOV.CONCEPTO,MOV.DES_TRANSACCION) DET_TRANSACCION,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR2,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,9,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BAN_INTERMEDIARIO_CORTO,
              MOV.COD_OFICINA COD_OFICINA,
             -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
              MOV.COD_USUARIO CAJERO,
              MOV.HORA HORA2
            FROM gv_movimientos_ast MOV, GE_AST_TRANSACCIONES ATR
            WHERE MOV.COD_MODULO = ATR.COD_MODULO
              AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
              AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
              AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
              AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
              AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE

              AND MOV.REVERSADO = 'N'
              AND FECHA = PAI_AST.FU_OBT_FEC_PROCESO
              --AND TRUNC(FECHA) = PAI_AST.FU_OBT_FEC_PROCESO
              --para el control de transferencias HBank a terceros
              AND ((ATR.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I') AND MOV.COD_USUARIO = 'HBANK'
                  AND (INSTR(MOV.CONCEPTO,'Transf. a',1,1)>0 AND  INSTR(MOV.CONCEPTO,' desde ',1,1)>0
                  OR(MOV.CONCEPTO = 'Pago de Sueldo ')OR (MOV.CONCEPTO = 'Pago de Aguinaldo '))
                  )OR (ATR.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I')OR MOV.COD_USUARIO != 'HBANK'))


              --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                  AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND ATR.Cod_Ast_Transaccion IN (252,210)--(cuando se recibe cheques)
                  AND PAI_AST.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO,MOV.COD_USUARIO,MOV.FECHA,MOV.NRO_CUENTA,MOV.COD_TIP_MOVIMIENTO,MOV.MONTO)= 'N'--se excluye los cheq devueltos
                  )OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I'OR ATR.Cod_Ast_Transaccion NOT IN (252,210)))


              )MOVI
      WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.ORIGINADOR--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I') ))

                 AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR--<control>
                   AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E','TRASFN-I') ))

        AND EXISTS ( SELECT 1
                   FROM GE_CTA_IMP_ASSIST X
                   WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA

                 );




    --
  BEGIN
    --
    IF P_AGREGA = 'S' THEN
      V_TIPO := 'a'; -- append
    ELSE
      V_TIPO := 'w'; -- reWrite
    END IF;
    --

      -- Abro el archivo
      IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, P_NOM_ARCHIVO, V_TIPO, 32767);
      END IF;


         CASE
           WHEN P_NOM_ARCHIVO = 'TG'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_GRUPO_TRANSACCIONES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;

           WHEN P_NOM_ARCHIVO = 'CT'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_COD_TRANSACCIONES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
           WHEN P_NOM_ARCHIVO = 'PA'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_PAISES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
           WHEN P_NOM_ARCHIVO = 'ES'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_DEPARTAMENTOS LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
           WHEN P_NOM_ARCHIVO = 'RE'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_REGIONES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'MO'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_MONEDAS LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
                  null;
            WHEN P_NOM_ARCHIVO = 'SU'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_SUCURSALES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'FU'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_OFICIALES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'TC'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_TIPO_CUENTAS LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'CP'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_PROPOSITO_CUENTA LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'OC'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_OBJETIVO_CUENTA LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'OF'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_ORIGEN_FONDO LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'CR'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_TIPO_RELACION LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'CL'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_CLIENTES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'CU'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_CUENTAS LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
            WHEN P_NOM_ARCHIVO = 'RC'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_RELACIONES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;
             WHEN P_NOM_ARCHIVO = 'TR'||PAI_AST.FU_OBT_FEC_PROCESO||'.TXT' THEN
                  --SE GRABAN LOS DETALLES
                  FOR F_CURSOR IN C_TRANSACCIONES LOOP
                    UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
                  END LOOP;


            ELSE
              NULL;
              END CASE;


      -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
      --

  EXCEPTION
    WHEN OTHERS THEN
      RETURN;
  END;

  -- Inserta datos de Clientes y Cuentas de ASSIST en un temporal.
  PROCEDURE PR_INS_CTA_ASSIST
  IS
    V_CONTADOR NUMBER;

    CURSOR C_CURSOR IS
      SELECT CTACLI.NRO_CUENTA, CTACLI.COD_PERSONA, PAI_AST.FU_OBT_FEC_PROCESO FEC_PROCESO
      FROM GE_CTA_CLIENTES CTACLI, GE_CLIENTES CLI, GE_CUENTAS CTA, BA_PERSONAS PER
      WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
         AND CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
         AND CTACLI.COD_PERSONA = PER.COD_PERSONA
         AND TRUNC(CLI.FEC_INSERCION) <= TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
         AND ( CTACLI.COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR CTACLI.COD_MODULO = 6 )
         AND NOT EXISTS ( SELECT 1
                          FROM GE_CTA_IMP_ASSIST
                          WHERE NRO_CUENTA = CTACLI.NRO_CUENTA
                            AND COD_PERSONA = CTACLI.COD_PERSONA );
  BEGIN
    -- Inicializar parámetros ITGF.
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo:=1;
    -- Elimino registros de la fecha para volver a cargarlo
    BEGIN
      DELETE GE_CTA_IMP_ASSIST
       WHERE TRUNC(FEC_PROCESO) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al eliminar registros de la fecha '||sqlerrm);
    END;
    -- Confirmo la eliminación.
    COMMIT;
    -- Inserta las cuentas que GE_CTA_IMP_ASSIST que se informarán a ASSIST
    V_CONTADOR := 0;
    --
    FOR F_CURSOR IN C_CURSOR LOOP
      V_CONTADOR := V_CONTADOR + 1;
      INSERT INTO GE_CTA_IMP_ASSIST (NRO_CUENTA, COD_PERSONA, FEC_PROCESO) VALUES (F_CURSOR.NRO_CUENTA, F_CURSOR.COD_PERSONA, F_CURSOR.FEC_PROCESO);
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
      raise_application_error(-20000,'Error al cargar temporal de cuentas para ASSIST'||sqlerrm);
  END;

  ------LAYOUTS CATALOGOS

  -- Archivo de Grupos de Transacciones.
  PROCEDURE PR_GEN_ARC_GRU_TRA(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    --
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_GRUPO_TRANSACCIONES IS
        -- ARCHIVO DE GRUPO DE TRANSACCIONES
        -- NOMBRE DEL ARCHIVO: TG20131231.TXT
        SELECT LPAD(COD_GRU_TRANSACCION,8,' ')||
        LPAD(DESCRIPCION,100,' ')CADENA
        FROM GE_GRU_TRA_ASSIST
        WHERE FEC_ENVIO IS NULL
          OR TRUNC(FEC_INSERCION) <= TRUNC(P_FEC_PROCESO)
          OR TRUNC(FEC_MODIFICACION) = TRUNC(P_FEC_PROCESO);


  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='TG'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';

    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;
    --SE GRABAN LOS DETALLES
    FOR F_CURSOR IN C_GRUPO_TRANSACCIONES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;
    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);

    -- Actualizo fecha de envio a ASSIST.
    BEGIN
      UPDATE GE_GRU_TRA_ASSIST
      SET FEC_ENVIO = PAI_AST.FU_OBT_FEC_PROCESO
      WHERE FEC_ENVIO IS NULL
        OR TRUNC(FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
        OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO);
      --
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al actualizar fecha de envio de grupos de transacciones '||sqlerrm);
    END;
    --
    COMMIT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de cod Transacciones.
  PROCEDURE PR_GEN_ARC_TRANSACCIONES(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    CURSOR C_COD_TRANSACCIONES IS
    SELECT LPAD(COD_AST_TRANSACCION,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||
      DECODE(TIPO,'C','I','D','O')||DECODE(IND_MONITOREO,'N','N','S','Y')||
      LPAD(COD_GRU_TRANSACCION,8,' ') CADENA
    FROM GE_AST_TRANSACCIONES
    WHERE /*( COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR COD_MODULO = 6)
      AND */( FEC_ENVIO IS NULL
            OR TRUNC(FEC_INSERCION) <= P_FEC_PROCESO
            OR TRUNC(FEC_MODIFICACION) = P_FEC_PROCESO );

  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='CT'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle

    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;
    --SE GRABAN LOS DETALLES
    FOR F_CURSOR IN C_COD_TRANSACCIONES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;
    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    -- Actualizar registros
    BEGIN
      UPDATE GE_AST_TRANSACCIONES
       SET FEC_ENVIO = PAI_AST.FU_OBT_FEC_PROCESO
        WHERE /*( COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR COD_MODULO = 6 )
           AND */( FEC_ENVIO IS NULL
                 OR TRUNC(FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                 OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
               );
      --
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al actualizar los registros de transacciones '||sqlerrm);
    END;
    --
    COMMIT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de  Países.
  PROCEDURE PR_GEN_ARC_PAISES(P_FEC_PROCESO IN DATE) IS

    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar

    CURSOR C_PAISES IS
    SELECT LPAD(COD_AST_PAIS,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||
      LPAD(COD_RIE_PAIS,3,' ')||'  '||
      LPAD(DECODE(COD_RIE_INT_PAIS,NULL,COD_RIE_PAIS,COD_RIE_INT_PAIS),3,' ')||'  ' CADENA
    FROM GE_AST_PAISES
    WHERE FEC_ENVIO IS NULL
      OR TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='PA'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;
    --SE GRABAN LOS DETALLES
    FOR F_CURSOR IN C_PAISES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;
    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
    -- Actualiza fecha de envio
    BEGIN
      UPDATE GE_AST_PAISES
      SET FEC_ENVIO =  PAI_AST.FU_OBT_FEC_PROCESO
      WHERE FEC_ENVIO IS NULL
        OR TRUNC(FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
        OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO);
      --
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al actualizar fecha de envio en PAISES'||sqlerrm);
    END;
    --
    COMMIT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Estados
  PROCEDURE PR_GEN_ARC_DEPARTAMENTOS(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar


  CURSOR C_DEPARTAMENTOS IS
    -- ARCHIVO DE ESTADOS (DEPARTAMENTOS)
    -- NOMBRE DEL ARCHIVO: ES20131231.TXT
    SELECT LPAD(COD_DEPARTAMENTO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ')||' '||LPAD('PRY',8,' ') CADENA
    FROM BA_DEPARTAMENTOS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='ES'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';

    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_DEPARTAMENTOS LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Regiones
  PROCEDURE PR_GEN_ARC_REGIONES(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
   CURSOR C_REGIONES IS
    -- ARCHIVO DE REGIONES (DEPARTAMENTOS)
    -- NOMBRE DEL ARCHIVO: RE20131231.TXT
    SELECT LPAD(COD_DEPARTAMENTO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_DEPARTAMENTOS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
     OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;

  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='RE'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_REGIONES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Oficinas
  PROCEDURE PR_GEN_ARC_SUCURSALES(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    CURSOR C_SUCURSALES IS
    -- ARCHIVO DE SUCURSALES
    -- NOMBRE DEL ARCHIVO: SU20131231.TXT
    SELECT LPAD(COD_OFICINA,10,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_OFICINAS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='SU'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalles
    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_SUCURSALES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Monedas
  PROCEDURE PR_GEN_ARC_MONEDAS(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_MONEDAS IS
    -- ARCHIVO DE MONEDAS
    -- NOMBRE DEL ARCHIVO: MO20131231.TXT
    SELECT LPAD(COD_MONEDA,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM BA_MONEDAS
    WHERE TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='MO'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_MONEDAS LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Oficial de Cuentas
  PROCEDURE PR_GEN_ARC_OFI_CTA(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_OFICIALES IS
    -- ARCHIVO DE OFICIALES
    -- NOMBRE DEL ARCHIVO: FU20131231.TXT
    SELECT DISTINCT RPAD(TRIM(COD_USUARIO),20,' ')||LPAD(SUBSTR(NOMBRE,1,80),80,' ')||TO_CHAR(FEC_INGRESO,'MM/DD/YYYY')CADENA
    FROM BA_USUARIOS
    WHERE ( NVL(OFICIAL,'N') IN ('S','N')
      AND ( TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO ) )
      OR (COD_USUARIO IN ('PY00763','PY00107','PY00365',
      'PY00403','PY00108','PY00171','PY00441','PY00146','PY00027',
      'PY00500','PY00137','PY00329','XPY9212','PY00258','BBVA','MIGRA')
      AND ( TRUNC(FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO )
      OR TRUNC(FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO) ) );
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='FU'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle (se agrega usuarios que no son oficiales porque están asignados todavía a clientes y da error al
    -- importar el archivo de clientes).
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_OFICIALES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de tipos de cuentas
  PROCEDURE PR_GEN_ARC_TIP_CTA(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    CURSOR C_TIPO_CUENTAS IS
    -- ARCHIVO DE TIPO DE CUENTAS
    -- NOMBRE DEL ARCHIVO: TC20131231.TXT
    SELECT LPAD(COD_MODALIDAD,8,' ')||LPAD(replace((SUBSTR(DESCRIPCION,1,40)),chr(10),''),40,' ') CADENA
    FROM GE_MODALIDADES
    WHERE ( COD_MODALIDAD IN (31,32,33,41,42,45,442,455) OR COD_MODULO = 6 )
      AND TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='TC'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_TIPO_CUENTAS LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de propósito de cuentas
  PROCEDURE PR_GEN_ARC_PRO_CTA(P_FEC_PROCESO IN DATE) IS
    -- Variable local
    V_COD_PROPOSITO GE_PRO_CUENTAS.COD_PROPOSITO%TYPE;
    -- Cursor que recupera otros propositos de la tabla de perfiles de cliente que aun no fue informado a ASSIST
    CURSOR CU_PRO_OTROS IS
      SELECT DISTINCT UPPER(P.PRO_OTROS) PRO_OTROS
      FROM CR_INF_FONDOS P
      WHERE P.PRO_OTROS IS NOT NULL
        AND NOT EXISTS ( SELECT 1 FROM GE_PRO_CUENTAS
                         WHERE DESCRIPCION = UPPER(P.PRO_OTROS)
                       );
    CURSOR C_PROPOSITO_CUENTA IS
    -- ARCHIVO DE PROPOSITO DE LA CUENTA
    -- NOMBRE DEL ARCHIVO: CP20131231.TXT
    SELECT LPAD(COD_PROPOSITO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM GE_PRO_CUENTAS WHERE DESCRIPCION IS NOT NULL
      AND TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO;
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='CP'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Recupera el maximo codigo de proposito de cuenta.
    BEGIN
      SELECT MAX(COD_PROPOSITO)
       INTO V_COD_PROPOSITO
        FROM GE_PRO_CUENTAS;
    EXCEPTION
      WHEN OTHERS THEN
        V_COD_PROPOSITO := 0;
    END;
    -- Recorre el cursor
    FOR c IN cu_pro_otros
    LOOP
      v_cod_proposito := nvl(v_cod_proposito, 0) + 1;
      BEGIN
        -- Inserta en la tabla de propitos para ASSIST.
        INSERT INTO GE_PRO_CUENTAS (COD_PROPOSITO, DESCRIPCION)
             VALUES (v_cod_proposito, c.pro_otros);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000,'Error al insertar el prósito de la cuenta. '||sqlerrm);
      END;
    END LOOP;
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_PROPOSITO_CUENTA LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Objetivo de cuentas
  PROCEDURE PR_GEN_ARC_OBJ_CTA(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_OBJETIVO_CUENTA IS
    -- ARCHIVO DE OBJETIVO DE LA CUENTA
    -- NOMBRE DEL ARCHIVO: OC20131231.TXT
    SELECT LPAD(VAL_MINIMO,8,' ')||LPAD(SUBSTR(UPPER(SIGNIFICADO),1,40),40,' ') CADENA
    FROM BA_COD_REFERENCIAS
    WHERE DOMINIO = 'DTM_RIESGO'
      AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO);
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='OC'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_OBJETIVO_CUENTA LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

   -- Archivo de origen de fondos
  PROCEDURE PR_GEN_ARC_ORI_FDO(P_FEC_PROCESO IN DATE) IS
    -- Varibles locales
    V_COD_ORI_FONDO GE_ORI_FONDOS.COD_ORI_FONDO%TYPE;
    -- Cursor que recupera los origenes de fondos que todavia no se informaron a ASSIST.
    CURSOR CU_ORI_FONDOS IS
      SELECT DISTINCT UPPER(P.FON_OTROS) FON_OTROS
      FROM CR_INF_FONDOS p
      WHERE P.FON_OTROS IS NOT NULL
        AND NOT EXISTS ( SELECT 1 FROM GE_ORI_FONDOS
                         WHERE DESCRIPCION = UPPER(P.FON_OTROS)
                       );
     CURSOR C_ORIGEN_FONDO IS
    -- ARCHIVO DE ORIGEN DE FONDOS
    -- NOMBRE DEL ARCHIVO: OF20131231.TXT
    SELECT LPAD(COD_ORI_FONDO,8,' ')||LPAD(SUBSTR(DESCRIPCION,1,40),40,' ') CADENA
    FROM GE_ORI_FONDOS WHERE DESCRIPCION IS NOT NULL
      AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO
      --DYDMR-3024 ITGF - Error importacion ASSIST
      OR nvl(V_REPROCESO, 'N') = 'N' AND TRUNC(FEC_INSERCION) = TRUNC(SYSDATE));

    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar

  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='OF'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Obtiene el último código de origen de fondos.
    BEGIN
      SELECT MAX(COD_ORI_FONDO)
       INTO V_COD_ORI_FONDO
        FROM GE_ORI_FONDOS;
    EXCEPTION
      WHEN OTHERS THEN
        V_COD_ORI_FONDO := 0;
    END;
    -- Recorre el cursor
    FOR c IN cu_ori_fondos LOOP
      v_cod_ori_fondo := nvl(v_cod_ori_fondo, 0) + 1;
      BEGIN
        INSERT INTO GE_ORI_FONDOS (COD_ORI_FONDO, DESCRIPCION)
             VALUES (v_cod_ori_fondo, c.fon_otros);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000,'Error al insertar en la tabla GE_ORI_FONDOS. '||sqlerrm);
      END;
    END LOOP;
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_ORIGEN_FONDO LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Tipos de Relaciones
  PROCEDURE PR_GEN_ARC_TIP_REL(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_TIPO_RELACION IS
    -- ARCHIVO DE TIPO DE RELACION
    -- NOMBRE DEL ARCHIVO: CR20131231.TXT
      SELECT LPAD(SUBSTR(VAL_MINIMO,1,8),8,' ')||LPAD(SUBSTR(SIGNIFICADO,1,30),30,' ')||LPAD(SUBSTR(VAL_MAXIMO,1,8),8,' ') CADENA
      FROM BA_COD_REFERENCIAS WHERE DOMINIO = 'AST_RELACION';
        /*AND (TRUNC(FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
        OR TRUNC(FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO);*/
  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='CR'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_TIPO_RELACION LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Clientes
  PROCEDURE PR_GEN_ARC_CLIENTES(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    CURSOR C_CLIENTES IS
            SELECT DISTINCT  replace(( RPAD(CTACLI.COD_PERSONA,20,' ')||                               /*(1)Número de Cliente*/ /*Layouts_Assist_Clientes_V3.0.0.doc*/
               RPAD(DECODE(PER.TIPO,'F','FISICA','J','JURIDICA'),8,' ')||               /*(2)Tipo de Cliente*/
               RPAD(PAI_AST.FU_OBT_NOM_CLIENTE(CTACLI.COD_PERSONA, PER.TIPO),80,' ')||  /*(3)Primer Nombre del Cliente*/
               RPAD(PAI_AST.FU_OBT_APE_CLIENTE(CTACLI.COD_PERSONA, PER.TIPO),80,' ')||  /*(4)Apellidos del Cliente/Nombre del Negocio*/
               'N'||                                                                    /*(5)Grupo Económico (grupo de empresas)*/
               LPAD(PER.NRO_DOCUMENTO,30,' ')||                                         /*(6)Número de Identificación de Documento*/
               LPAD(PAI_AST.FU_OBT_DES_TIP_DOC(PER.COD_TIP_DOCUMENTO),50,' ')||         /*(7)Tipo de Documento de Identificación*/
               LPAD(UPPER(PAI_AST.FU_OBT_DES_ACTIVIDAD(CTACLI.COD_PERSONA, PER.TIPO)),50,' ')||/*(8)Ocupación*/
               LPAD(PAI_AST.FU_OBT_FEC_NACIMIENTO(CTACLI.COD_PERSONA, PER.TIPO),10,' ')||  /*(9)Fecha de Nacimiento*/
               RPAD(PAI_AST.FU_OBT_COD_ISO_PAIS(CTACLI.COD_PERSONA, 'N',NULL),8,' ')||     /*(10)País de Nacionalidad*/
               RPAD(PAI_AST.FU_OBT_COD_ISO_PAIS(CTACLI.COD_PERSONA, 'D',NULL),8,' ')||     /*(11)País de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DIR_PRINCIPAL(CTACLI.COD_PERSONA),120,' ')||            /*(12)Campo para Dirección 1*/
               LPAD(' ',120,' ')||                                                         /*(13)Campo para Dirección 2*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'C'),50,' ')||      /*(14)Ciudad de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'D'),8,' ')||       /*(15)Estado de Domicilio*/
               LPAD(PAI_AST.FU_OBT_DES_DEP_CIU_POS(CTACLI.COD_PERSONA, 'P'),10,' ')||      /*(16)Código Postal del Domicilio*/
               LPAD(PAI_AST.FU_OBT_TEL_PRINCIPAL(CTACLI.COD_PERSONA),20,' ')||             /*(17)Número de Teléfono 1*/
               LPAD(' ',20,' ')||                                                          /*(18)Número de Teléfono 2*/
               LPAD(NVL(PER.DIR_CORREO,' '),50,' ')||                                      /*(19)Email*/
               PAI_AST.FU_OBT_PEP(CTACLI.COD_PERSONA)||                                    /*(20)Persona Políticamente Expuesta*/
               LPAD(decode((FUE_OBT_ARL_CLI(CTACLI.COD_PERSONA)),'BAJO',1,'MEDIO',2,'ALTO',3,0),4,' ')|| /*(21)Código de Riesgo*/
                                                                                           /*(22)Fuente de Patrimonio (riqueza)*/
               RPAD(PAI_AST.FU_OBT_TIP_OBJ_CUENTA(CTACLI.COD_PERSONA),8,' ')||             /*(23)Tipo del Objetivo*/
               LPAD(TO_CHAR(PAI_AST.FU_OBT_FEC_ING_CLIENTE(CTACLI.COD_PERSONA),'MM/DD/YYYY'),10,' ') ),chr(10), ' ') CADENA/*(24)Fecha de Comienzo (fecha de captación)*/
                                                                                      /*(25)Fecha de Terminación       */
               FROM GE_CTA_CLIENTES CTACLI, GE_CLIENTES CLI, BA_PERSONAS PER
               WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
                 AND CTACLI.COD_PERSONA = PER.COD_PERSONA
                 AND ( TRUNC(CLI.FEC_INSERCION) <= TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                        OR TRUNC(CLI.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                     )
                 AND EXISTS ( SELECT 1
                              FROM GE_CTA_IMP_ASSIST X
                              WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                                AND X.COD_PERSONA = CTACLI.COD_PERSONA
                             );

  BEGIN
    --Nombre del Archivo.
    V_NOM_ARCHIVO :='CL'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
    -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_CLIENTES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Cuentas
  PROCEDURE PR_GEN_ARC_CUENTAS(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
  CURSOR C_CUENTAS IS

      -- ARCHIVO DE CUENTAS
      -- NOMBRE DEL ARCHIVO: CU20131231.TXT
      SELECT LPAD(CTACLI.NRO_CUENTA,20,' ')||
             LPAD(CTACLI.COD_PERSONA,20,' ')||
             LPAD(

               REPLACE (CTA.DENOMINACION,CHR(10),' ')

             ,80,' ')||
             LPAD(FUG_OBT_OFI_OFICIAL(CTACLI.COD_PERSONA),10,' ')||
             LPAD(CTA.COD_MONEDA,8,' ')||
             LPAD(CLI.COD_USU_OFICIAL,20,' ')||
             LPAD('PRY',8,' ')||
             LPAD(PAI_AST.FU_OBT_REGION_CUENTA(CLI.COD_OFICINA),8,' ')||
             LPAD(TO_CHAR(CTA.FEC_APERTURA,'MM/DD/YYYY'),10,' ')||
             LPAD(PAI_AST.FU_OBT_FEC_CANCELACION(CTACLI.NRO_CUENTA, CTACLI.COD_MODULO, CTACLI.COD_MODALIDAD,'2'),10,' ')||
             --LPAD(PAI_AST.FU_OBT_FEC_MADURACION,10,' ')||--SE TIENE QUE TRAER LA FECHA DE VENCIMIENTO DE LA CUENTA
             LPAD(PAI_AST.FU_OBT_FEC_CANCELACION(CTACLI.NRO_CUENTA, CTACLI.COD_MODULO, CTACLI.COD_MODALIDAD,'1'),10,' ')||
             LPAD(' ',3,' ')||
             LPAD(' ',1,' ')||
             LPAD(' ',20,' ')||
             LPAD(CTA.COD_MODALIDAD,8,' ')||
             LPAD(' ',8,' ')||
             LPAD(DECODE(PAI_AST.FU_OBT_PRO_CUENTAS(CTACLI.COD_PERSONA),'0',' ',PAI_AST.FU_OBT_PRO_CUENTAS(CTACLI.COD_PERSONA)),8,' ')||
             LPAD(PAI_AST.FU_OBT_TIP_OBJ_CUENTA(CTACLI.COD_PERSONA),8,' ')||
             LPAD(DECODE(PAI_AST.FU_OBT_FON_CUENTAS(CTACLI.COD_PERSONA),'0',' ',PAI_AST.FU_OBT_FON_CUENTAS(CTACLI.COD_PERSONA)),8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',8,' ')||
             LPAD(' ',20,' ')||
             LPAD('PRY',8,' ')||
             LPAD(DECODE(FUG_OBT_SIT_CUENTA(CTACLI.NRO_CUENTA),'N','Y','N'),1,' ')||
             '  '||
             LPAD('PRY',8,' ') CADENA
         FROM GE_CTA_CLIENTES CTACLI, GE_CUENTAS CTA, GE_CLIENTES CLI
          WHERE CTACLI.NRO_CUENTA = CTA.NRO_CUENTA
            AND CTACLI.COD_PERSONA = CLI.COD_PERSONA
            AND CTACLI.RELACION = 'P'
            AND (TRUNC(CLI.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
                    OR TRUNC(CLI.FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO
                   )
                   --and  CTACLI.cod_persona = 399531
            AND EXISTS ( SELECT 1 FROM GE_CTA_IMP_ASSIST X
                         WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                           AND X.COD_PERSONA = CTACLI.COD_PERSONA
                        );
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='CU'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_CUENTAS LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  EXCEPTION
      WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000,'Error al ejecutar la creacion del archivo '||v_nom_archivo||sqlerrm);
  END;

  -- Archivo de Relaciones de clientes cuentas
  PROCEDURE PR_GEN_ARC_RELACIONES(P_FEC_PROCESO IN DATE) IS

    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar

       CURSOR C_RELACIONES IS
    -- ARCHIVO DE RELACIONES CON CUENTAS
    -- NOMBRE DEL ARCHIVO: RC20131231.TXT
    SELECT RPAD(CTACLI.COD_PERSONA,20,' ')||RPAD(CTACLI.NRO_CUENTA,20,' ')||RPAD(CTACLI.RELACION,8,' ')||'I' CADENA
    FROM GE_CTA_CLIENTES CTACLI
    WHERE ( CTACLI.COD_MODALIDAD IN (31,32,33,41,42,45,442) OR CTACLI.COD_MODULO = 6 )
      AND CTACLI.RELACION != 'P'
      AND (TRUNC(CTACLI.FEC_INSERCION) <= PAI_AST.FU_OBT_FEC_PROCESO
      OR TRUNC(CTACLI.FEC_MODIFICACION) = PAI_AST.FU_OBT_FEC_PROCESO )
      AND EXISTS ( SELECT 1
                   FROM GE_CTA_IMP_ASSIST X
                   WHERE TRIM(X.NRO_CUENTA) = CTACLI.NRO_CUENTA
                      AND TRIM(X.COD_PERSONA) = CTACLI.COD_PERSONA )
    ORDER BY CTACLI.NRO_CUENTA;
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='RC'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_RELACIONES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
  END;

  -- Archivo de perfiles de clientes
  PROCEDURE PR_GEN_ARC_PERFILES(P_FEC_PROCESO IN DATE) IS
    --
    V_CONTADOR NUMBER;
    --
    CURSOR C_CURSOR IS
      SELECT DISTINCT ACT.COD_PERSONA COD_PERSONA
      FROM CR_ACT_ESPERADAS ACT, GE_COTIZACIONES G
      WHERE ACT.FECHA = G.FECHA
        AND G.COD_MONEDA = 'USD'
        AND ROUND(ACT.MTO_PRO_CREDITO/G.VAL_CONVERSION) > 0
        AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
        AND (TRUNC(ACT.FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
              OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
             )
        AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                     WHERE X.COD_PERSONA = ACT.COD_PERSONA
                    )
      UNION ALL
        SELECT DISTINCT ACT.COD_PERSONA COD_PERSONA
          FROM CR_ACT_ESPERADAS ACT, GE_COTIZACIONES G
           WHERE ACT.FECHA = G.FECHA
              AND G.COD_MONEDA = 'USD'
              AND ROUND(ACT.MTO_PRO_DEBITO/G.VAL_CONVERSION)  > 0
              AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
              AND (TRUNC(ACT.FEC_INSERCION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                    OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                    )
              AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                          WHERE X.COD_PERSONA = ACT.COD_PERSONA
                         )
      ORDER BY 1;


    CURSOR C_PERFILES IS
    -- ARCHIVO DE PERFILES
    -- NOMBRE DEL ARCHIVO: PL20131231.TXT
    SELECT ACT.COD_PERSONA,
      'INC' TIPO,
      RPAD(ACT.COD_PERSONA,20,' ')||
      'A'||
      RPAD('INC',8,' ')||
      ' 1'||
      '12'||
      LPAD(CAN_TRA_CREDITO,10,' ')||

      LPAD(FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA),20,' ')||
      '  1' CADENA
    FROM CR_ACT_ESPERADAS ACT
    WHERE  FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) > 1
      AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
      AND ACT.FECHA = ( SELECT MAX(FECHA)
                                       FROM CR_ACT_ESPERADAS
                                       WHERE COD_PERSONA = ACT.COD_PERSONA
                                      )
      AND (TRUNC(ACT.FEC_INSERCION) = PAI_AST.FU_OBT_FEC_PROCESO
            OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
           )
      AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                   WHERE X.COD_PERSONA = ACT.COD_PERSONA
                 )
    UNION ALL
      SELECT ACT.COD_PERSONA,
             'OUT',
             RPAD(ACT.COD_PERSONA,20,' ')||
             'A'||
             RPAD('OUT',8,' ')||
             ' 1'||
             '12'||
             LPAD(CAN_TRA_DEBITO,10,' ')||

             LPAD(FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_DEBITO, NULL, ACT.FECHA),20,' ')||
             '  1' CADENA
        FROM CR_ACT_ESPERADAS ACT
         WHERE FUB_CON_MON_A_MONEDA(ACT.COD_MONEDA,'USD',ACT.MTO_PRO_CREDITO, NULL, ACT.FECHA) > 1 -- SE USA EL CAMPO MTO_PRO_CREDITO PARA QUE ENTRE SU PAR, POR MAS QUE SEA MENOR A 1 USD
            AND PAI_AST.FU_VER_CLI_PRINCIPAL(ACT.COD_PERSONA) = 'S'
            AND ACT.FECHA = ( SELECT MAX(FECHA)
                                       FROM CR_ACT_ESPERADAS
                                       WHERE COD_PERSONA = ACT.COD_PERSONA
                                      )
            AND (TRUNC(ACT.FEC_INSERCION) = PAI_AST.FU_OBT_FEC_PROCESO
                  OR TRUNC(ACT.FEC_MODIFICACION) = TRUNC(PAI_AST.FU_OBT_FEC_PROCESO)
                  )
            AND EXISTS ( SELECT DISTINCT 1 FROM GE_CTA_IMP_ASSIST X
                        WHERE X.COD_PERSONA = ACT.COD_PERSONA
                        );
    --ORDER BY 1,2;
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar

    --
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='PL'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle
    FOR F_CURSOR IN C_PERFILES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea
    END LOOP;

    -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
    --
    -- Actualiza la fecha de envio del perfil
    BEGIN
      V_CONTADOR := 0;
      --
      FOR F_CURSOR IN C_CURSOR LOOP
        --
        V_CONTADOR := V_CONTADOR + 1;
        --
        UPDATE GE_CTA_IMP_ASSIST
        SET FEC_ENV_PERFIL = PAI_AST.FU_OBT_FEC_PROCESO
        WHERE COD_PERSONA = F_CURSOR.COD_PERSONA;
        --
        IF V_CONTADOR = 1000 THEN
          COMMIT;
          V_CONTADOR := 0;
        END IF;
      END LOOP;
      --
      COMMIT;
      --
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al actualizar la fecha de envio de perfil. ERROR: '||SQLERRM);
    END;
    --
  END;



  PROCEDURE PR_GEN_ARC_USER_DEFINED(P_FEC_PROCESO IN DATE) IS
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar

    cursor C_CAMPOS IS--clientes frecuentes y gestores de clientes
    SELECT distinct
    RPAD(CTACLI.COD_PERSONA,20,' ')||--cod_cliente
    RPAD('FRECUENTE',40,' ')|| --LABEL
    RPAD(decode(f.cli_frecuente,'S','SI','N','NO','NO'),200,' ')CADENA

               FROM GE_CTA_CLIENTES CTACLI, GE_CLIENTES CLI, BA_PERSONAS PER, cr_inf_fondos f
               WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
                 AND CTACLI.COD_PERSONA = PER.COD_PERSONA
                 and CTACLI.COD_PERSONA = f.cod_persona (+)
                 AND ( TRUNC(CLI.FEC_INSERCION) <= P_FEC_PROCESO
                        OR TRUNC(CLI.FEC_MODIFICACION) = P_FEC_PROCESO
                     )
                 AND EXISTS ( SELECT 1
                              FROM GE_CTA_IMP_ASSIST X
                              WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                                AND X.COD_PERSONA = CTACLI.COD_PERSONA
                             )

    UNION ALL

    SELECT DISTINCT  replace(( RPAD(CTACLI.COD_PERSONA,20,' ')||
                           RPAD('GESTOR',40,' ')||
                           RPAD(BU.NOMBRE,200,' ')
                          ) ,chr(10), ' ') CADENA

       FROM GE_CTA_CLIENTES CTACLI, GE_CLIENTES CLI, BA_PERSONAS PER, BA_USUARIOS BU
       WHERE CTACLI.COD_PERSONA = CLI.COD_PERSONA
         AND CTACLI.COD_PERSONA = PER.COD_PERSONA
         AND CLI.COD_USU_OFICIAL = BU.COD_USUARIO
         AND ( TRUNC(CLI.FEC_INSERCION) <=  P_FEC_PROCESO
                OR TRUNC(CLI.FEC_MODIFICACION) = P_FEC_PROCESO
             )
         AND EXISTS ( SELECT 1
                      FROM GE_CTA_IMP_ASSIST X
                      WHERE X.NRO_CUENTA = CTACLI.NRO_CUENTA
                        AND X.COD_PERSONA = CTACLI.COD_PERSONA
                     );

    BEGIN
      -- Nombre del Archivo.
    V_NOM_ARCHIVO :='FC'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle
     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
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
  PROCEDURE PR_GEN_ARC_MOVIMIENTOS(P_FEC_PROCESO IN DATE) IS
    V_CONTADOR NUMBER;
    V_FILE         UTL_FILE.FILE_TYPE;
    V_PATH         VARCHAR2(200)  := 'ASSIST';
    V_TIPO         VARCHAR2(1)    := 'w';  -- w-reemplazar / a-agregar
    --Acumuladores--
    --V_ACU_MONTO_D NUMBER(18,3):= 0;
    --V_ACU_MONTO_C NUMBER(18,3):= 0;
    --V_ACU_REGS_D NUMBER(10):= 0;
    --V_ACU_REGS_C NUMBER(10):= 0;

    ---- DYDMR-10243 ---
   v_cotizacion_usd   GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('USD',PAI_AST.FU_OBT_FEC_PROCESO);
   v_cotizacion_eur   GE_COTIZACIONES.VAL_CONVERSION%type := FUG_OBT_COTIZACION('EUR',PAI_AST.FU_OBT_FEC_PROCESO);
   v_redondeo         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,'USD');
   
     CURSOR C_TRANSACCIONES IS

      SELECT LPAD(
      DECODE(MOVI.COD_GRU_TRANSACCION,'TRASFI-I',
                                      DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                       '372',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                       MOVI.COD_AST_TRANSACCION),
                                       'TRASFI-E',
                                       DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                       '191',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                       MOVI.COD_AST_TRANSACCION),
                                       MOVI.COD_AST_TRANSACCION)
      ,8,' ')||
        LPAD(MOVI.MONTO,20,' ')||
        LPAD(MOVI.FEC_VALOR,10,' ')||
        LPAD(MOVI.NRO_CUENTA,20,' ')||
        LPAD(MOVI.CONCEPTO,40,' ')||
        LPAD(MOVI.MONTO_ORIGINAL,20,' ')||
        LPAD(MOVI.COD_MONEDA,8,' ')||
        LPAD(PAI_AST.FU_OBT_NUM_CANAL_TRANSACCION(MOVI.CAJERO),4,' ')||
        LPAD(MOVI.HORA,8,' ')||
        LPAD(replace(MOVI.ORIGINADOR,chr(10), ' '),140,' ')||--para quitar los ENTERs
        LPAD(MOVI.BANCO_EMISOR,40,' ')||
        LPAD(MOVI.BANCO_INTERMEDIARIO,40,' ')||
        LPAD(MOVI.BANCO_BENEFICIARIO,40,' ')||
        LPAD(replace(replace(MOVI.BENEFICIARIO, chr(10), ' '), chr(13), ' '), 140, ' ') ||
        LPAD(MOVI.COD_PAI_BANCO_EMISOR,10,' ')||
        LPAD(' ',40,' ')||
        LPAD(MOVI.COD_PAI_BANCO_BENEFIARIO,8,' ')||
        LPAD(REPLACE(REPLACE(REPLACE(MOVI.DET_TRANSACCION,CHR(10),' '),CHR(13),' '), chr(124), '°'), 500) ||--REEMPLAZAMOS LOS | POR ° PARA no generar error al importar al assist
        LPAD(MOVI.FEC_VALOR2,10,' ')||
        LPAD(MOVI.BAN_INTERMEDIARIO_CORTO,8,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',1,' ')||
        LPAD(MOVI.COD_OFICINA,10,' ')||
        LPAD(MOVI.CAJERO,20,' ')||
        LPAD(MOVI.HORA2,11,' ')||
        LPAD(' ',38,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',6,' ') CADENA, MOVI.COD_TIP_MOVIMIENTO, MOVI.MONTO, MOVI.HORA,DECODE(MOVI.COD_GRU_TRANSACCION,'TRASFI-I',
                                                                                DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                                                                 '372',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                                                                 MOVI.COD_AST_TRANSACCION),
                                                                                 'TRASFI-E',
                                                                                 DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                                                                 '191',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                                                                 MOVI.COD_AST_TRANSACCION),
                                                                                 MOVI.COD_AST_TRANSACCION) COD_AST_TRANSACCION
      FROM (SELECT ATR.COD_AST_TRANSACCION COD_AST_TRANSACCION,
              --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_AST.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
              round(DECODE(MOV.COD_MONEDA,'USD', MOV.MONTO,
                                         'EUR',((MOV.MONTO * v_cotizacion_eur )/v_cotizacion_usd),
                                         'GS',MOV.MONTO / v_cotizacion_usd,0),v_redondeo) MONTO,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR,
              MOV.NRO_CUENTA NRO_CUENTA,
              --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
              MOV.DES_TRANSACCION CONCEPTO,
              MOV.MONTO MONTO_ORIGINAL,
              MOV.COD_MONEDA COD_MONEDA,
              MOV.COD_MODALIDAD COD_MODALIDAD,
              MOV.HORA HORA,
              ATR.COD_GRU_TRANSACCION,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,2,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') ORIGINADOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,3,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,4,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_INTERMEDIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,5,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,6,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,7,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,8,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_BENEFIARIO,
              REPLACE(replace(NVL(MOV.CONCEPTO,MOV.DES_TRANSACCION),chr(13)||chr(10), ' '),chr(10),' ') DET_TRANSACCION,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR2,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,9,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,MOV.COD_TIP_MOVIMIENTO,MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BAN_INTERMEDIARIO_CORTO,
              MOV.COD_OFICINA COD_OFICINA,
             -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
              MOV.COD_USUARIO CAJERO,
              MOV.HORA HORA2,
              ATR.TIPO COD_TIP_MOVIMIENTO--MOV.COD_TIP_MOVIMIENTO
            FROM GV_MOVIMIENTOS_AST MOV, GE_AST_TRANSACCIONES ATR
            WHERE MOV.COD_MODULO = ATR.COD_MODULO
              AND MOV.COD_MODALIDAD = ATR.COD_MODALIDAD
              AND MOV.COD_TRANSACCION = ATR.COD_TRANSACCION
              AND MOV.COD_MOD_PADRE = ATR.COD_MOD_PADRE
              AND MOV.COD_MAD_PADRE = ATR.COD_MAD_PADRE
              AND MOV.COD_TRA_PADRE = ATR.COD_TRA_PADRE

              AND MOV.REVERSADO = 'N'
              AND FECHA = P_FEC_PROCESO
              --AND TRUNC(FECHA) = PAI_AST.FU_OBT_FEC_PROCESO
              --para el control de transferencias HBank a terceros
              AND ((ATR.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I') AND MOV.COD_USUARIO = 'HBANK'
                  AND (INSTR(MOV.CONCEPTO,'Transf. a',1,1)>0 AND  INSTR(MOV.CONCEPTO,' desde ',1,1)>0
                  OR(MOV.CONCEPTO = 'Pago de Sueldo ')OR (MOV.CONCEPTO = 'Pago de Aguinaldo '))
                  )OR (ATR.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I')OR MOV.COD_USUARIO != 'HBANK'))


              --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                  AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND ATR.Cod_Ast_Transaccion IN (252,210)--(cuando se recibe cheques)
                  AND PAI_AST.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO,MOV.COD_USUARIO,MOV.FECHA,MOV.NRO_CUENTA,MOV.COD_TIP_MOVIMIENTO,MOV.MONTO)= 'N'--se excluye los cheq devueltos
                  )OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I'OR ATR.Cod_Ast_Transaccion NOT IN (252,210)))


              )MOVI
      WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.ORIGINADOR--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I') ))

                 AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR--<control>
                   AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E','TRASFN-I') ))

        AND EXISTS ( SELECT 1
                   FROM GE_CTA_IMP_ASSIST X
                   WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA

                 );
       -----------------------------------------------------------------------------
       CURSOR C_TRANSACCIONES_GE IS

       SELECT LPAD(
      DECODE(MOVI.COD_GRU_TRANSACCION,'TRASFI-I',
                                      DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                       '372',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                       MOVI.COD_AST_TRANSACCION),
                                       'TRASFI-E',
                                       DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                       '191',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                       MOVI.COD_AST_TRANSACCION),
                                       MOVI.COD_AST_TRANSACCION)
      ,8,' ')||
        LPAD(MOVI.MONTO,20,' ')||
        LPAD(MOVI.FEC_VALOR,10,' ')||
        LPAD(MOVI.NRO_CUENTA,20,' ')||
        LPAD(MOVI.CONCEPTO,40,' ')||
        LPAD(MOVI.MONTO_ORIGINAL,20,' ')||
        LPAD(MOVI.COD_MONEDA,8,' ')||
        LPAD(PAI_AST.FU_OBT_NUM_CANAL_TRANSACCION(MOVI.CAJERO),4,' ')||
        LPAD(MOVI.HORA,8,' ')||
        LPAD(replace(MOVI.ORIGINADOR,chr(10), ' '),140,' ')||--para quitar los ENTERs
        LPAD(MOVI.BANCO_EMISOR,40,' ')||
        LPAD(MOVI.BANCO_INTERMEDIARIO,40,' ')||
        LPAD(MOVI.BANCO_BENEFICIARIO,40,' ')||
        LPAD(replace(replace(MOVI.BENEFICIARIO, chr(10), ' '), chr(13), ' '), 140, ' ') ||
        LPAD(MOVI.COD_PAI_BANCO_EMISOR,10,' ')||
        LPAD(' ',40,' ')||
        LPAD(MOVI.COD_PAI_BANCO_BENEFIARIO,8,' ')||
        LPAD(REPLACE(REPLACE(REPLACE(MOVI.DET_TRANSACCION,CHR(10),' '),CHR(13),' '), chr(124), '°'), 500) ||--REEMPLAZAMOS LOS | POR ° PARA no generar error al importar al assist
        LPAD(MOVI.FEC_VALOR2,10,' ')||
        LPAD(MOVI.BAN_INTERMEDIARIO_CORTO,8,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',1,' ')||
        LPAD(MOVI.COD_OFICINA,10,' ')||
        LPAD(MOVI.CAJERO,20,' ')||
        LPAD(MOVI.HORA2,11,' ')||
        LPAD(' ',38,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',140,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',40,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',14,' ')||
        LPAD(' ',6,' ') CADENA, MOVI.TIPO COD_TIP_MOVIMIENTO, MOVI.MONTO, MOVI.HORA,DECODE(MOVI.COD_GRU_TRANSACCION,'TRASFI-I',
                                                                                    DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                                                                     '372',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                                                                     MOVI.COD_AST_TRANSACCION),
                                                                                     'TRASFI-E',
                                                                                     DECODE(MOVI.COD_PAI_BANCO_EMISOR,MOVI.COD_PAI_BANCO_BENEFIARIO,
                                                                                                                     '191',--372:COD DE TRANSFERENCIA NACIAL DE INGRESO
                                                                                                                     MOVI.COD_AST_TRANSACCION),
                                                                                     MOVI.COD_AST_TRANSACCION)   COD_AST_TRANSACCION
      FROM (SELECT ATR.COD_AST_TRANSACCION COD_AST_TRANSACCION,
              --FUB_CON_MON_A_MONEDA(MOV.COD_MONEDA,'USD',MOV.MONTO, NULL, PAI_AST.FU_OBT_FEC_PROCESO) MONTO, --DYDMR-10243
              round(DECODE(MOV.COD_MONEDA,'USD', MOV.MONTO,
                                         'EUR',((MOV.MONTO * v_cotizacion_eur )/v_cotizacion_usd),
                                         'GS',MOV.MONTO / v_cotizacion_usd,0),v_redondeo) MONTO,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR,
              MOV.NRO_CUENTA NRO_CUENTA,
              --SUBSTR( FUG_OBT_DES_TRANSACCION(MOV.COD_MODULO, MOV.COD_MODALIDAD, MOV.COD_TRANSACCION),1,40) CONCEPTO,
              TR.DESCRIPCION CONCEPTO,
              MOV.MONTO MONTO_ORIGINAL,
              MOV.COD_MONEDA COD_MONEDA,
              MOV.COD_MODALIDAD COD_MODALIDAD,
              MOV.HORA HORA,
              ATR.COD_GRU_TRANSACCION,
              ATR.TIPO TIPO,--DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO) TIPO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,2,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') ORIGINADOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,3,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,4,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_INTERMEDIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,5,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BANCO_BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,6,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BENEFICIARIO,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,7,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_EMISOR,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,8,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') COD_PAI_BANCO_BENEFIARIO,
              replace(replace(NVL(MOV.CONCEPTO,TR.DESCRIPCION),chr(13)||chr(10), ' '),chr(10),' ') DET_TRANSACCION,
              TO_CHAR(MOV.FECHA,'MM/DD/YYYY') FEC_VALOR2,
              NVL(PAI_AST.FU_OBT_DAT_TRANSFERENCIA(MOV.NRO_DOCUMENTO,MOV.NRO_CUENTA,9,MOV.HORA,MOV.COD_USUARIO,MOV.FECHA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.COD_TRA_PADRE,MOV.COD_TRANSACCION,ATR.COD_GRU_TRANSACCION,MOV.COD_BANCO,MOV.MONTO),' ') BAN_INTERMEDIARIO_CORTO,
              MOV.COD_OFICINA COD_OFICINA,
             -- FUG_OBT_OFI_OFICIAL (FUG_OBT_CLI_PRINCIPAL(MOV.NRO_CUENTA)) OFI_OFICIAL,--(1)para obtener la oficina del gestor
              MOV.COD_USUARIO CAJERO,
              MOV.HORA HORA2
            FROM GE_MOVIMIENTOS MOV, GE_AST_TRANSACCIONES ATR, GE_TRANSACCIONES TR
            WHERE MOV.COD_MODULO = ATR.COD_MODULO
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
              AND (ATR.cod_modulo in( 3,4,6) OR (ATR.cod_modulo = 9 AND ATR.cod_mod_padre in( 3,4,6)))



              AND MOV.REVERSADO = 'N'

             AND FECHA = P_FEC_PROCESO
              --and fecha = to_date('27/03/2014','DD/MM/YYYY')
              --AND TRUNC(FECHA) = PAI_AST.FU_OBT_FEC_PROCESO
              --para el control de transferencias HBank a terceros
              AND ((ATR.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I') AND MOV.COD_USUARIO = 'HBANK'
                  AND (INSTR(MOV.CONCEPTO,'Transf. a',1,1)>0 AND  INSTR(MOV.CONCEPTO,' desde ',1,1)>0
                  OR(MOV.CONCEPTO = 'Pago de Sueldo ')OR (MOV.CONCEPTO = 'Pago de Aguinaldo '))
                  )OR (ATR.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I')OR MOV.COD_USUARIO != 'HBANK'))


              --para el control de transferencias CHEQ-I  no deben de ir el movimiento integral del cheques devuelto (mov crédito y débito)
                  AND ((ATR.COD_GRU_TRANSACCION = 'CHEQ-I' AND ATR.Cod_Ast_Transaccion IN (252,210)--(cuando se recibe cheques)
                  AND PAI_AST.FU_OBT_IND_CHEQ_DEVUELTO(MOV.NRO_DOCUMENTO,MOV.COD_USUARIO,MOV.FECHA,MOV.NRO_CUENTA,DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TR.TIPO),MOV.MONTO)= 'N'--se excluye los cheq devueltos
                  )OR (ATR.COD_GRU_TRANSACCION != 'CHEQ-I'OR ATR.Cod_Ast_Transaccion NOT IN (252,210)))


              )MOVI
      WHERE MOVI.MONTO > 0

            AND ((MOVI.COD_GRU_TRANSACCION IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.ORIGINADOR--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRNINT-E','TRNINT-I','TRASFN-E','TRASFN-I') ))

                 AND ((MOVI.COD_GRU_TRANSACCION IN ('TRASFN-E','TRASFN-I')
                   AND MOVI.BENEFICIARIO != MOVI.BANCO_EMISOR--<control>
                   AND MOVI.ORIGINADOR != MOVI.BANCO_BENEFICIARIO--<control>
                 )OR (MOVI.COD_GRU_TRANSACCION NOT IN ('TRASFN-E','TRASFN-I') ))

        AND EXISTS ( SELECT 1
                   FROM GE_CTA_IMP_ASSIST X
                   WHERE X.NRO_CUENTA = MOVI.NRO_CUENTA

                 );
  BEGIN
    -- Nombre del Archivo.
    V_NOM_ARCHIVO :='TR'||TO_CHAR(P_FEC_PROCESO,'YYYYMMDD')||'.TXT';
    -- Detalle

     -- Generar archivo
    IF UTL_FILE.IS_OPEN (V_FILE) = FALSE THEN
        V_FILE := UTL_FILE.FOPEN(V_PATH, V_NOM_ARCHIVO, V_TIPO, 32767);
    END IF;

    -- Detalle

    IF V_REPROCESO = 'N' THEN
       V_CONTADOR := 0;
      FOR F_CURSOR IN C_TRANSACCIONES_GE LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea

        V_CONTADOR := V_CONTADOR + 1;
        --registra el movimiento en un histórico.
        INSERT INTO GE_AST_MOVIMIENTOS_LOG VALUES(P_FEC_PROCESO,F_CURSOR.HORA,
                                                  F_CURSOR.COD_AST_TRANSACCION,
                                                  F_CURSOR.MONTO,F_CURSOR.COD_TIP_MOVIMIENTO,'NORMAL');
        IF V_CONTADOR = 10000 THEN
          COMMIT;
          V_CONTADOR := 0;
        END IF;

      END LOOP;

      COMMIT;

      -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
      --
    ELSE
      FOR F_CURSOR IN C_TRANSACCIONES LOOP
        UTL_FILE.PUT_LINE(V_FILE, F_CURSOR.CADENA); -- graba una linea

         V_CONTADOR := V_CONTADOR + 1;
        --registra el movimiento en un histórico.
        INSERT INTO GE_AST_MOVIMIENTOS_LOG VALUES(P_FEC_PROCESO,F_CURSOR.HORA,
                                                  F_CURSOR.COD_AST_TRANSACCION,
                                                  F_CURSOR.MONTO,F_CURSOR.COD_TIP_MOVIMIENTO,'REPROCESO');

         IF V_CONTADOR = 10000 THEN
          COMMIT;
          V_CONTADOR := 0;
         END IF;

      END LOOP;

      COMMIT;
      -- Cierra el archivo
      UTL_FILE.FCLOSE(V_FILE);
      --
    END IF;


  END;


 /* --- PROCEDIMIENTO PRINCIPAL QUE GENERA TODOS LOS ARCHIVOS ---
  PROCEDURE PR_GEN_ARC_ASSIST_FINAL
  IS
  BEGIN
    -- Inicializar variables de entorno ITGF
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo:=1;
    -- Cargo la fecha de proceso del calendario
    V_REPROCESO := 'N';
    --
    V_FEC_PROCESO := PAI_AST.FU_OBT_FEC_PROCESO;
    -- Verifico si todavia no se procesó, si ya se proceso en la fecha utilizar el reproceso.
    IF NOT PAI_AST.FU_VER_FEC_PROCESO(V_FEC_PROCESO) THEN
      -- Cargo los clientes de la fecha
      PR_INS_CTA_ASSIST;
      -------- LAYOUTS CATALOGO ---------------------------------------
      PR_GEN_ARC_GRU_TRA(V_FEC_PROCESO);        -- (5) Grupo de transacciones--
      PR_GEN_ARC_TRANSACCIONES(V_FEC_PROCESO);  -- (4) Transacciones--
      PR_GEN_ARC_PAISES(V_FEC_PROCESO);         -- (6) Países--
      PR_GEN_ARC_DEPARTAMENTOS(V_FEC_PROCESO);  -- (7) Estados = Departamentos--
      PR_GEN_ARC_REGIONES(V_FEC_PROCESO);       -- (8) Regiones = Departamentos--
      PR_GEN_ARC_SUCURSALES(V_FEC_PROCESO);     -- (9) Sucursales--
      PR_GEN_ARC_MONEDAS(V_FEC_PROCESO);        -- (10) Monedas--
      PR_GEN_ARC_OFI_CTA(V_FEC_PROCESO);        -- (11) Oficiales de Cuentas--
      PR_GEN_ARC_TIP_CTA(V_FEC_PROCESO);        -- (12) Tipo de Cuenta--
      PR_GEN_ARC_PRO_CTA(V_FEC_PROCESO);        -- (14) Propósito de la Cuenta--
      PR_GEN_ARC_OBJ_CTA(V_FEC_PROCESO);        -- (15) Tipo de Objetivo de la Cuenta--
      PR_GEN_ARC_ORI_FDO(V_FEC_PROCESO);        -- (16) Origen de Fondos--
      -- PR_GEN_ARC_ORI_PAT;                    -- (17) Origen de Patrimonio (NO SE VA A ENVIAR)
      PR_GEN_ARC_TIP_REL(V_FEC_PROCESO);        -- (26) Tipo de Relación--
      -------- LAYOUTS CLIENTES ---------------------------------------
      PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);       -- (21) Clientes--
      -------- LAYOUTS CUENTAS  ---------------------------------------
      PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);        -- (1) Cuentas--
      PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);     -- (24) Relaciones--
      -------- LAYOUTS PERFILES ---------------------------------------
      PR_GEN_ARC_PERFILES(V_FEC_PROCESO);       -- (22) Perfiles de Clientes
      -------- LAYOUTS DE OPERACIONES ---------------------------------
      PR_GEN_ARC_MOVIMIENTOS(V_FEC_PROCESO);    -- (3) Transacciones (movimientos)
      --
    ELSE
      RAISE_APPLICATION_ERROR(-20001,'Ya se proceso la fecha '||V_FEC_PROCESO);
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al ejecutar Creacion de Archivos para ASSIST'||sqlerrm);
  END;*/

  --- PROCEDIMIENTO PRINCIPAL QUE GENERA TODOS LOS ARCHIVOS ---
  PROCEDURE PR_GEN_ARC_ASSIST
  IS
  BEGIN
    -- Inicializar variables de entorno ITGF
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo:=1;
    -- Cargo la fecha de proceso del calendario
    V_REPROCESO := 'N';
    --
    --seteamos que los decimales sean PUNTOS
    pre_cam_for_numerico('.,');
    --
    V_FEC_PROCESO := PAI_AST.FU_OBT_FEC_PROCESO;
    -- Verifico si todavia no se procesó, si ya se proceso en la fecha utilizar el reproceso.
    IF NOT PAI_AST.FU_VER_FEC_PROCESO(V_FEC_PROCESO) THEN
      -- Cargo los clientes de la fecha
      PR_INS_CTA_ASSIST;
      -------- LAYOUTS CATALOGO ---------------------------------------
      PR_GEN_ARC_GRU_TRA(V_FEC_PROCESO);        -- (5) Grupo de transacciones--
      PR_GEN_ARC_TRANSACCIONES(V_FEC_PROCESO);  -- (4) Transacciones--
      PR_GEN_ARC_PAISES(V_FEC_PROCESO);         -- (6) Países--
      PR_GEN_ARC_DEPARTAMENTOS(V_FEC_PROCESO);  -- (7) Estados = Departamentos--
      PR_GEN_ARC_REGIONES(V_FEC_PROCESO);       -- (8) Regiones = Departamentos--
      PR_GEN_ARC_SUCURSALES(V_FEC_PROCESO);     -- (9) Sucursales--
      PR_GEN_ARC_MONEDAS(V_FEC_PROCESO);        -- (10) Monedas--
      PR_GEN_ARC_OFI_CTA(V_FEC_PROCESO);        -- (11) Oficiales de Cuentas--
      PR_GEN_ARC_TIP_CTA(V_FEC_PROCESO);        -- (12) Tipo de Cuenta--
      PR_GEN_ARC_PRO_CTA(V_FEC_PROCESO);        -- (14) Propósito de la Cuenta--
      PR_GEN_ARC_OBJ_CTA(V_FEC_PROCESO);        -- (15) Tipo de Objetivo de la Cuenta--
      PR_GEN_ARC_ORI_FDO(V_FEC_PROCESO);        -- (16) Origen de Fondos--
      -- PR_GEN_ARC_ORI_PAT;                    -- (17) Origen de Patrimonio (NO SE VA A ENVIAR)
      PR_GEN_ARC_TIP_REL(V_FEC_PROCESO);        -- (26) Tipo de Relación--
      -------- LAYOUTS CLIENTES ---------------------------------------
      PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);       -- (21) Clientes--
      -------- LAYOUTS CUENTAS  ---------------------------------------
      PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);        -- (1) Cuentas--
      PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);     -- (24) Relaciones--
      -------- LAYOUTS PERFILES ---------------------------------------
      PR_GEN_ARC_PERFILES(V_FEC_PROCESO);       -- (22) Perfiles de Clientes
      -------- USER DEFINED CONSTUMER ---------------------------------------
      PR_GEN_ARC_USER_DEFINED(V_FEC_PROCESO);       -- () Perfiles de Clientes

      -------- LAYOUTS DE OPERACIONES ---------------------------------
      PR_GEN_ARC_MOVIMIENTOS(V_FEC_PROCESO);    -- (3) Transacciones (movimientos)
      --
    ELSE
      RAISE_APPLICATION_ERROR(-20001,'Ya se proceso la fecha '||V_FEC_PROCESO);
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al ejecutar Creacion de Archivos para ASSIST'||sqlerrm);
  END;

  -- Regeneración de archivos a una fecha dada que ya se haya procesado.
  PROCEDURE PR_REGEN_ARC_ASSIST
  IS
  BEGIN
    -- Inicializar variables de entorno ITGF
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo:=1;
    --
    V_REPROCESO := 'S';
    -- Si es automatico viene nulo, si es por demanda viene con la fecha que indica el usuario.
    V_FEC_PROCESO := PAI_AST.FU_OBT_FEC_PROCESO;
    --
    --seteamos que los decimales sean PUNTOS
    pre_cam_for_numerico('.,');
    --
    IF V_FEC_PROCESO IS NOT NULL THEN
      -- Cargo los clientes de la fecha
      PR_INS_CTA_ASSIST;
      -------- LAYOUTS CATALOGO ---------------------------------------
      PR_GEN_ARC_GRU_TRA(V_FEC_PROCESO);        -- (5) Grupo de transacciones
      PR_GEN_ARC_TRANSACCIONES(V_FEC_PROCESO);  -- (4) Transacciones
      PR_GEN_ARC_PAISES(V_FEC_PROCESO);         -- (6) Países
      PR_GEN_ARC_DEPARTAMENTOS(V_FEC_PROCESO);  -- (7) Estados = Departamentos
      PR_GEN_ARC_REGIONES(V_FEC_PROCESO);       -- (8) Regiones = Departamentos
      PR_GEN_ARC_SUCURSALES(V_FEC_PROCESO);     -- (9) Sucursales
      PR_GEN_ARC_MONEDAS(V_FEC_PROCESO);        -- (10) Monedas
      PR_GEN_ARC_OFI_CTA(V_FEC_PROCESO);        -- (11) Oficiales de Cuentas
      PR_GEN_ARC_TIP_CTA(V_FEC_PROCESO);        -- (12) Tipo de Cuenta
      PR_GEN_ARC_PRO_CTA(V_FEC_PROCESO);        -- (14) Propósito de la Cuenta
      PR_GEN_ARC_OBJ_CTA(V_FEC_PROCESO);        -- (15) Tipo de Objetivo de la Cuenta
      PR_GEN_ARC_ORI_FDO(V_FEC_PROCESO);        -- (16) Origen de Fondos
      -- PR_GEN_ARC_ORI_PAT;                    -- (17) Origen de Patrimonio (NO SE VA A ENVIAR)
      PR_GEN_ARC_TIP_REL(V_FEC_PROCESO);        -- (26) Tipo de Relación
      -------- LAYOUTS CLIENTES ---------------------------------------
      PR_GEN_ARC_CLIENTES(V_FEC_PROCESO);       -- (21) Clientes
      -------- LAYOUTS CUENTAS  ---------------------------------------
      PR_GEN_ARC_CUENTAS(V_FEC_PROCESO);        -- (1) Cuentas
      PR_GEN_ARC_RELACIONES(V_FEC_PROCESO);     -- (24) Relaciones
      -------- LAYOUTS PERFILES ---------------------------------------
      PR_GEN_ARC_PERFILES(V_FEC_PROCESO);       -- (22) Perfiles de Clientes
      -------- USER DEFINED CONSTUMER ---------------------------------------
      PR_GEN_ARC_USER_DEFINED(V_FEC_PROCESO);       -- () Perfiles de Clientes
      -------- LAYOUTS DE OPERACIONES ---------------------------------
      PR_GEN_ARC_MOVIMIENTOS(V_FEC_PROCESO);    -- (3) Transacciones (movimientos)
      --
    ELSE
      RAISE_APPLICATION_ERROR(-20000,'No está configurado la fecha de proceso en el parámetro ');
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al ejecutar Creacion de Archivos para ASSIST'||sqlerrm);
  END;
END PAI_AST;
/

