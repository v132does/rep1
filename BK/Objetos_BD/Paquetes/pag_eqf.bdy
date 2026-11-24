CREATE OR REPLACE PACKAGE BODY IT.PAG_EQF IS

  PROCEDURE LP_REG_OPERACION(P_MENSAJE   IN LONG,
                             P_RESPUESTA IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    V_RESPUESTA BA_LOG_MENSAJERIA.RESPUESTA%TYPE;
  BEGIN
    V_RESPUESTA := SUBSTR(P_RESPUESTA, 1, 4000);
    INSERT INTO BA_LOG_MENSAJERIA
      (MENSAJE, RESPUESTA)
    VALUES
      (P_MENSAJE, V_RESPUESTA);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM);
  END;

  FUNCTION FU_OBT_TIP_DOCUMENTO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS
    V_TIP_DOCUMENTO VARCHAR2(10);
  BEGIN
    BEGIN
      SELECT TD.ABREVIATURA
      INTO V_TIP_DOCUMENTO
      FROM BA_PERSONAS T, BA_TIP_DOCUMENTOS TD
      WHERE T.COD_PERSONA = P_COD_PERSONA
      AND T.COD_TIP_DOCUMENTO = TD.COD_TIP_DOCUMENTO;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        G_MSG_ERROR := G_MSG_ERROR ||
                       'No existe el tipo de Documento de la Persona';
        RAISE G_ERROR;
      
      WHEN OTHERS THEN
        G_MSG_ERROR := G_MSG_ERROR ||
                       'Error al buscar el tipo de documento: ' || SQLERRM;
        RAISE G_ERROR;
    END;
  
    RETURN V_TIP_DOCUMENTO;
  END;

  FUNCTION FU_OBT_NOM_REPORTEPDF(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS
    V_TIP_DOCUMENTO      VARCHAR2(5);
    V_NRO_IDENTIFICACION VARCHAR2(5);
    V_NRO_CLIENTE        VARCHAR2(9);
    V_COD_SUCURSAL       BA_OFICINAS.COD_OFICINA%TYPE;
    V_FEC_ESCANEO        VARCHAR2(8);
    V_HOR_ESCANEO        VARCHAR2(6);
    V_NOM_REPORTE        VARCHAR2(500);
  
  BEGIN
    BEGIN
      SELECT LPAD(P.COD_TIP_DOCUMENTO, 3, 0) TIP_DOCUMENTO,
             LPAD(1, 3, 0) NRO_IDENTIF,
             LPAD(P.COD_PERSONA, 9, 0) NRO_CLIENTE,
             LPAD(C.COD_OFICINA, 2, 0) SUCURSAL,
             TO_CHAR(PAG_CAL.FU_OBT_FEC_ACTUAL(1), 'RRRRMMDD'),
             TO_CHAR(SYSDATE, 'hh24miss') HORA
      INTO V_TIP_DOCUMENTO,
           V_NRO_IDENTIFICACION,
           V_NRO_CLIENTE,
           V_COD_SUCURSAL,
           V_FEC_ESCANEO,
           V_HOR_ESCANEO
      FROM BA_PERSONAS P, GE_CLIENTES C
      WHERE P.COD_PERSONA = P_COD_PERSONA
      AND C.COD_PERSONA = P.COD_PERSONA;
    END;
    V_NOM_REPORTE := V_TIP_DOCUMENTO || '_' || V_NRO_IDENTIFICACION || '_' ||
                     V_NRO_CLIENTE || '_' || V_COD_SUCURSAL || '_' ||
                     V_FEC_ESCANEO || '_' || V_HOR_ESCANEO || '.PDF';
  
    RETURN V_NOM_REPORTE;
  END;

  FUNCTION FU_DEC_BASE64(INBASE64CHAR IN OUT NOCOPY CLOB) RETURN CLOB IS
  
    BLOB_LOC  BLOB;
    CLOB_TRIM CLOB;
    RES       CLOB;
  
    LANG_CONTEXT INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
    DEST_OFFSET  INTEGER := 1;
    SRC_OFFSET   INTEGER := 1;
    READ_OFFSET  INTEGER := 1;
    WARNING      INTEGER;
    CLOBLEN      INTEGER := DBMS_LOB.GETLENGTH(INBASE64CHAR);
  
    AMOUNT       INTEGER := 1440; -- must be a whole multiple of 4
    BUFFER       RAW(1440);
    STRINGBUFFER VARCHAR2(1440);
    -- BASE64 characters are always simple ASCII. Thus you get never any Mulit-Byte character and having the same size as 'amount' is sufficient
  
  BEGIN
  
    IF INBASE64CHAR IS NULL
       OR NVL(CLOBLEN, 0) = 0 THEN
      RETURN NULL;
    ELSIF CLOBLEN <= 32000 THEN
      RETURN UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(INBASE64CHAR)));
    END IF;
    -- UTL_ENCODE.BASE64_DECODE is limited to 32k, process in chunks if bigger
  
    -- Remove all NEW_LINE from base64 string
    CLOBLEN := DBMS_LOB.GETLENGTH(INBASE64CHAR);
    DBMS_LOB.CREATETEMPORARY(CLOB_TRIM, TRUE);
    LOOP
      EXIT WHEN READ_OFFSET > CLOBLEN;
      STRINGBUFFER := REPLACE(REPLACE(DBMS_LOB.SUBSTR(INBASE64CHAR, AMOUNT, READ_OFFSET), CHR(13), NULL), CHR(10), NULL);
      DBMS_LOB.WRITEAPPEND(CLOB_TRIM, LENGTH(STRINGBUFFER), STRINGBUFFER);
      READ_OFFSET := READ_OFFSET + AMOUNT;
    END LOOP;
  
    READ_OFFSET := 1;
    CLOBLEN     := DBMS_LOB.GETLENGTH(CLOB_TRIM);
    DBMS_LOB.CREATETEMPORARY(BLOB_LOC, TRUE);
    LOOP
      EXIT WHEN READ_OFFSET > CLOBLEN;
      BUFFER := UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(CLOB_TRIM, AMOUNT, READ_OFFSET)));
      DBMS_LOB.WRITEAPPEND(BLOB_LOC, DBMS_LOB.GETLENGTH(BUFFER), BUFFER);
      READ_OFFSET := READ_OFFSET + AMOUNT;
    END LOOP;
  
    DBMS_LOB.CREATETEMPORARY(RES, TRUE);
    DBMS_LOB.CONVERTTOCLOB(RES, BLOB_LOC, DBMS_LOB.LOBMAXSIZE, DEST_OFFSET, SRC_OFFSET, DBMS_LOB.DEFAULT_CSID, LANG_CONTEXT, WARNING);
  
    DBMS_LOB.FREETEMPORARY(BLOB_LOC);
    DBMS_LOB.FREETEMPORARY(CLOB_TRIM);
    RETURN RES;
  
  END;

  FUNCTION FU_ENV_TCP_MSJCLOB(P_SERVIDOR   IN VARCHAR2,
                              P_PUERTO     IN NUMBER,
                              P_TIE_ESPERA IN NUMBER,
                              P_MENSAJE    IN LONG,
                              P_RESPUESTA  OUT CLOB)
  
    /*INFORMACIÓN IMPORTANTE: esta función es una copia de FUE_ENV_TCP_MENSAJES la diferencia
    es que FUE_ENV_TCP_MSJCLOB retorna la respuesta en tipo
    de dato CLOB */
  
    /* PARAMETROS
    *  p_servidor   : direccion ip del servidor
    *  p_puerto     : nro. de puerto
    *  p_tie_espera : tiempo de espera en segundos
    *  p_mensaje    : mensaje a enviar
    *  p_respuesta  : valor de retorno
    */
   RETURN VARCHAR2 IS
    V_CON            UTL_TCP.CONNECTION;
    V_OK             VARCHAR2(1) := 'N';
    V_LON            PLS_INTEGER;
    V_PARTES_XML     BLOB;
    V_RESPUESTA_XML  BLOB;
    V_RESPUESTA_RAW  LONG RAW(1000);
    V_RESPUESTA_CLOB CLOB;
    --V_ERROR          varchar2(4000);
    V_CONTADOR NUMBER(10) := 0;
  
    PROCEDURE LP_REG_OPERACION(P_MENSAJE   IN LONG,
                               P_RESPUESTA IN CLOB) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      V_RESPUESTA BA_LOG_MENSAJERIA.RESPUESTA%TYPE;
    BEGIN
      V_RESPUESTA := SUBSTR(P_RESPUESTA, 1, 4000);
      INSERT INTO BA_LOG_MENSAJERIA
        (MENSAJE, RESPUESTA)
      VALUES
        (P_MENSAJE, V_RESPUESTA);
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, SQLERRM);
    END;
  BEGIN
    BEGIN
      V_CON := UTL_TCP.OPEN_CONNECTION(REMOTE_HOST => P_SERVIDOR, REMOTE_PORT => P_PUERTO, TX_TIMEOUT => P_TIE_ESPERA, CHARSET => 'US7ASCII');
      V_LON := UTL_TCP.WRITE_LINE(V_CON, P_MENSAJE);
      --obtiene la totalidad del mensaje del socket
      BEGIN
        LOOP
          --V_RESPUESTA_XML := V_RESPUESTA_XML || UTL_TCP.GET_LINE(V_CON, true);
        
          V_RESPUESTA_RAW := UTL_TCP.GET_RAW(V_CON, 1000);
          V_PARTES_XML    := TO_BLOB(V_RESPUESTA_RAW);
          V_CONTADOR      := V_CONTADOR + 1;
        
          IF V_CONTADOR = 1 THEN
            V_RESPUESTA_XML := V_PARTES_XML;
          ELSE
            V_RESPUESTA_XML := FU_CONCAT_BLOB(V_RESPUESTA_XML, V_PARTES_XML);
          END IF;
        
        END LOOP;
      EXCEPTION
        WHEN UTL_TCP.END_OF_INPUT THEN
          NULL; -- end of input
      END;
    
      V_RESPUESTA_CLOB := PAG_EQF.FU_BLOB_TO_CLOB(V_RESPUESTA_XML);
    
      P_RESPUESTA := V_RESPUESTA_CLOB;
      -- V_RESPUESTA_RAW := UTL_TCP.GET_RAW(V_CON, 1000);
    
      --P_RESPUESTA := TO_BLOB(V_RESPUESTA_RAW);
      UTL_TCP.CLOSE_CONNECTION(V_CON);
      V_OK := 'S';
    EXCEPTION
      WHEN UTL_TCP.NETWORK_ERROR THEN
        UTL_TCP.CLOSE_CONNECTION(V_CON);
        P_RESPUESTA := '01-No hay conexion con el Servidor';
      WHEN UTL_TCP.TRANSFER_TIMEOUT THEN
        UTL_TCP.CLOSE_CONNECTION(V_CON);
        P_RESPUESTA := '02-Limite de tiempo de espera';
      WHEN OTHERS THEN
        UTL_TCP.CLOSE_CONNECTION(V_CON);
        P_RESPUESTA := SQLERRM;
        --V_ERROR     := sqlerrm;
    END;
    LP_REG_OPERACION(P_MENSAJE, P_RESPUESTA);
    RETURN(V_OK);
  END;

  FUNCTION FU_CLOB_TO_BLOB(ACLOB IN CLOB) RETURN BLOB IS
    RESULT BLOB;
    O1     INTEGER;
    O2     INTEGER;
    C      INTEGER;
    W      INTEGER;
  BEGIN
    O1 := 1;
    O2 := 1;
    C  := 0;
    W  := 0;
    DBMS_LOB.CREATETEMPORARY(RESULT, TRUE);
    DBMS_LOB.CONVERTTOBLOB(RESULT, ACLOB, LENGTH(ACLOB), O1, O2, 0, C, W);
    RETURN(RESULT);
  END;

  FUNCTION FU_BLOB_TO_CLOB(BLOB_IN IN BLOB) RETURN CLOB AS
    V_CLOB    CLOB;
    V_VARCHAR VARCHAR2(32767);
    V_START   PLS_INTEGER := 1;
    V_BUFFER  PLS_INTEGER := 32767;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(V_CLOB, TRUE);
  
    FOR I IN 1 .. CEIL(DBMS_LOB.GETLENGTH(BLOB_IN) / V_BUFFER)
    LOOP
    
      V_VARCHAR := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(BLOB_IN, V_BUFFER, V_START));
    
      DBMS_LOB.WRITEAPPEND(V_CLOB, LENGTH(V_VARCHAR), V_VARCHAR);
      V_START := V_START + V_BUFFER;
    END LOOP;
    RETURN V_CLOB;
  END;

  FUNCTION FU_CONCAT_BLOB(A IN BLOB,
                          B IN BLOB) RETURN BLOB IS
    C BLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(C, TRUE);
    DBMS_LOB.APPEND(C, A);
    DBMS_LOB.APPEND(C, B);
    RETURN C;
  END;

  PROCEDURE PR_GEN_ARC_PDF(P_NOM_ARCHIVO IN VARCHAR2,
                           P_DIR         IN VARCHAR2,
                           P_BLOB        IN BLOB) IS
  
    L_FILE     UTL_FILE.FILE_TYPE;
    L_BUFFER   RAW(32767);
    L_AMOUNT   BINARY_INTEGER := 32767;
    L_POS      INTEGER := 1;
    L_BLOB     BLOB;
    L_BLOB_LEN INTEGER;
  
  BEGIN
  
    L_BLOB := P_BLOB;
  
    L_BLOB_LEN := DBMS_LOB.GETLENGTH(L_BLOB);
  
    -- Open the destination file.
    --l_file := UTL_FILE.fopen('BLOBS','MyImage.gif','w', 32767);
    L_FILE := UTL_FILE.FOPEN(P_DIR, P_NOM_ARCHIVO, 'wb', 32767);
  
    -- Read chunks of the BLOB and write them to the file
    -- until complete.
    WHILE L_POS <= L_BLOB_LEN
    LOOP
      DBMS_LOB.READ(L_BLOB, L_AMOUNT, L_POS, L_BUFFER);
      UTL_FILE.PUT_RAW(L_FILE, L_BUFFER, TRUE);
      L_POS := L_POS + L_AMOUNT;
    END LOOP;
  
    -- Close the file.
    UTL_FILE.FCLOSE(L_FILE);
  
  EXCEPTION
    WHEN OTHERS THEN
      -- Close the file if something goes wrong.
      IF UTL_FILE.IS_OPEN(L_FILE) THEN
        UTL_FILE.FCLOSE(L_FILE);
      END IF;
      RAISE;
  END;

  PROCEDURE PR_OBT_PAR_SER_INFORMCONF(P_TIP_SERVICIO IN NUMBER,
                                      P_PAR_ENVIO    OUT VARCHAR2,
                                      P_NOM_SERVICIO OUT VARCHAR2) IS
  BEGIN
    SELECT A.ABREVIATURA, A.VAL_MINIMO
    INTO P_NOM_SERVICIO, P_PAR_ENVIO
    FROM BA_COD_REFERENCIAS A
    WHERE A.DOMINIO = 'PAR_SER_INFORMCONF'
    AND A.VAL_MAXIMO = P_TIP_SERVICIO;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -no existe datos para este servicio';
      RAISE G_ERROR;
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR ||
                     ' -error al buscar datos del servicio: ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_OBT_PAR_SER_INFOCHECK(P_TIP_SERVICIO IN NUMBER,
                                     P_PAR_ENVIO    OUT VARCHAR2,
                                     P_NOM_SERVICIO OUT VARCHAR2) IS
  BEGIN
    SELECT A.ABREVIATURA, A.VAL_MINIMO
    INTO P_NOM_SERVICIO, P_PAR_ENVIO
    FROM BA_COD_REFERENCIAS A
    WHERE A.DOMINIO = 'PAR_SER_INFOCHECK'
    AND A.VAL_MAXIMO = P_TIP_SERVICIO;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -no existe datos para este servicio';
      RAISE G_ERROR;
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR ||
                     ' -error al buscar datos del servicio: ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_INS_SOLICITUD_INF(P_NRO_SOLICITUD IN NUMBER,
                                 P_COD_PERSONA   BA_PERSONAS.COD_PERSONA%TYPE) IS
  BEGIN
    R_GE_EQF_SOLICITUDES.COD_PERSONA      := P_COD_PERSONA;
    R_GE_EQF_SOLICITUDES.FEC_CONSULTA     := G_FEC_ACTUAL;
    R_GE_EQF_SOLICITUDES.HOR_CONSULTA     := TO_CHAR(SYSDATE, 'hh24:mi:ss');
    R_GE_EQF_SOLICITUDES.USU_INSERCION    := USER;
    R_GE_EQF_SOLICITUDES.FEC_INSERCION    := SYSDATE;
    R_GE_EQF_SOLICITUDES.USU_MODIFICACION := USER;
    R_GE_EQF_SOLICITUDES.FEC_MODIFICACION := SYSDATE;
    R_GE_EQF_SOLICITUDES.NRO_SOLICITUD    := P_NRO_SOLICITUD;
    IF G_NOM_SERVICIO = 'informebyDocV2' THEN
      R_GE_EQF_SOLICITUDES.TIP_SERVICIO := 'INFOCHECK';
    ELSE
      R_GE_EQF_SOLICITUDES.TIP_SERVICIO := 'INFORMCONF';
    END IF;
  
    BEGIN
    
      INSERT INTO GE_EQF_SOLICITUDES
      VALUES R_GE_EQF_SOLICITUDES;
    EXCEPTION
      WHEN OTHERS THEN
        G_MSG_ERROR := G_MSG_ERROR ||
                       'Error al insertar datos de solicitud' || SQLERRM;
        RAISE G_ERROR;
    END;
  
  END;

  FUNCTION FU_OBT_NRO_SOLICITUD(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN NUMBER IS
    V_NRO_SOLICITUD NUMBER(5);
  
  BEGIN
    BEGIN
      SELECT MAX(T.NRO_SOLICITUD)
      INTO V_NRO_SOLICITUD
      FROM GE_EQF_SOLICITUDES T
      WHERE T.COD_PERSONA = P_COD_PERSONA;
    
      RETURN V_NRO_SOLICITUD;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        G_MSG_PROCESO := G_MSG_PROCESO ||
                         ' -No existen solicitudes anteriores de la Persona';
        RAISE G_ERROR;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error al obtener nro de solicitud pre-cargada: ' ||
                               SQLERRM);
    
  END;

  FUNCTION FU_OBT_TIP_PERSONA(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS
    V_TIP_PERSONA VARCHAR2(5);
  
  BEGIN
    BEGIN
      SELECT DECODE(T.TIPO, 'J', 'EM', 'F', 'PE', '--')
      INTO V_TIP_PERSONA
      FROM BA_PERSONAS T
      WHERE T.COD_PERSONA = P_COD_PERSONA;
    
      RETURN V_TIP_PERSONA;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        G_MSG_PROCESO := G_MSG_PROCESO ||
                         ' -No se encuentra datos de la persona';
        RAISE G_ERROR;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error al obtener datos de la persona: ' ||
                               SQLERRM);
    
  END;

  FUNCTION FU_OBT_NRO_DOCUMENTO(G_nro_documento IN ba_personas.nro_documento%TYPE)
    RETURN VARCHAR2 IS
    v_nro_documento ba_personas.nro_documento%TYPE;
    v_letra         VARCHAR2(10);
    /*Se crea funcion para enviar nro_documento con letra 24/05/22 C.O. DYDMR-23345*/
  BEGIN
    --FORMATEAR CON PUNTOS LA CEDULA
    BEGIN
      SELECT RTRIM(LTRIM(REPLACE(to_char(to_number(G_nro_documento), '999G999G999'), ',', '.')))
      INTO v_nro_documento
      FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        --ENTRA EN LA EXCEPCION CUANDO LA CEDULA TIENE LETRAS
        --SACAR LA LETRA
        BEGIN
          SELECT LTRIM(G_nro_documento,'0123456789')
          INTO v_letra
          FROM dual;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        --SACAR LA LETRA DE LA VARIABLE
        BEGIN
          SELECT REPLACE(G_nro_documento, v_letra, '')
          INTO v_nro_documento
          FROM DUAL;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        --FORMATEAR CON PUNTOS
        BEGIN
          SELECT RTRIM(LTRIM(REPLACE(to_char(to_number(v_nro_documento), '999G999G999'), ',', '.')))
          INTO v_nro_documento
          FROM DUAL;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        --CONCATENAR CON LA LETRA FINAL
        BEGIN
          SELECT v_nro_documento || v_letra
          INTO v_nro_documento
          FROM DUAL;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
    END;
    RETURN v_nro_documento;
  END;

  FUNCTION FU_VER_REG_ANTECEDENTES(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN BOOLEAN IS
    V_EXISTE  VARCHAR2(1);
    V_RETORNO BOOLEAN := FALSE;
  BEGIN
    BEGIN
      SELECT 'S'
      INTO V_EXISTE
      FROM GE_CLI_ANTECEDENTES A
      WHERE A.COD_PERSONA = P_COD_PERSONA;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        V_EXISTE := 'N';
      WHEN TOO_MANY_ROWS THEN
        V_EXISTE := 'S';
      WHEN OTHERS THEN
        V_EXISTE := 'N';
    END;
    IF NVL(V_EXISTE, 'N') = 'S' THEN
      V_RETORNO := TRUE;
    ELSE
      V_RETORNO := FALSE;
    END IF;
    RETURN V_RETORNO;
  END;

  PROCEDURE PR_ERR_MENSAJES(P_MENSAJE IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(-20000, P_MENSAJE);
  END;
  FUNCTION FU_OBT_DAT_INFORMCONF(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS
    V_FAJ_BURO      GE_CLI_ANTECEDENTES.FAJ_BURO%TYPE;
    V_NRO_DOCUMENTO BA_PERSONAS.NRO_DOCUMENTO%TYPE;
    V_PAR_INGRESO   VARCHAR2(22);
    V_RETORNO       VARCHAR2(2);
    V_RESPUESTA     VARCHAR2(4000);
    V_OK            VARCHAR2(1); -- indica si el socket se corto o no
    V_FEC_ACTUAL    DATE := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
  BEGIN
    V_NRO_DOCUMENTO := FUE_OBT_NRO_DOC_PERSONA(P_COD_PERSONA);
    V_NRO_DOCUMENTO := TRIM(REPLACE(TO_CHAR(V_NRO_DOCUMENTO, '999G999G999G999'), ',', '.'));
    V_PAR_INGRESO   := '02' || LPAD(V_NRO_DOCUMENTO, 15, ' ');
    --llama a socket
    V_OK := FUE_ENV_TCP_MENSAJES(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
    --v_ok        := 'S';
    V_RESPUESTA := '000O';
    IF V_OK != 'S' THEN
      PR_ERR_MENSAJES('Error con el Socket Informconf.');
    ELSE
      V_RETORNO := SUBSTR(V_RESPUESTA, 1, 2);
      IF V_RETORNO != '00' THEN
        --error en la conexion
        RETURN 'Informconf => ' || SUBSTR(V_RESPUESTA, 1, 2) || ' ' || SUBSTR(V_RESPUESTA, 3, LENGTH(V_RESPUESTA));
      ELSE
        --v_faj_buro := substr(v_respuesta, 4, 1);
        SELECT DBMS_RANDOM.STRING('U', 1)
        INTO V_FAJ_BURO
        FROM DUAL;
        WHILE V_FAJ_BURO NOT IN ('A', 'B', 'C', 'D', 'K', 'L', 'M', 'N')
        LOOP
          SELECT DBMS_RANDOM.STRING('U', 1)
          INTO V_FAJ_BURO
          FROM DUAL;
        END LOOP;
        -- Se asigna un valor para clientes con registro no encontrado en Informconf e Informconf bloqueado.
        IF V_FAJ_BURO = '0' THEN
          V_FAJ_BURO := 'P';
        ELSIF V_FAJ_BURO = '1' THEN
          V_FAJ_BURO := 'O';
        END IF;
        IF FU_VER_REG_ANTECEDENTES(P_COD_PERSONA) THEN
          UPDATE GE_CLI_ANTECEDENTES A
          SET A.FAJ_BURO = V_FAJ_BURO, A.FEC_ULT_INFORMCONF = V_FEC_ACTUAL
          WHERE A.COD_PERSONA = P_COD_PERSONA;
        ELSE
          INSERT INTO GE_CLI_ANTECEDENTES
            (COD_PERSONA, FAJ_BURO, FEC_ULT_INFORMCONF)
          VALUES
            (P_COD_PERSONA, V_FAJ_BURO, V_FEC_ACTUAL);
        END IF;
        RETURN 'Informconf => OK';
      END IF;
    END IF;
  END;

  PROCEDURE PR_ACT_DAT_INFOCHECK(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) IS
    V_CHE_RECHAZADOS     VARCHAR2(3) := 0;
    V_CHE_REC_HISTORICOS VARCHAR2(3) := 0;
    V_INHIBICIONES       VARCHAR2(3) := 0;
    V_INH_HISTORICAS     VARCHAR2(3) := 0;
    V_SIT_INFOCHEK       GE_CLI_ANTECEDENTES.SIT_INFOCHECK%TYPE;
  BEGIN
    --se obtiene los datos para la actualización en ge_cli_antecedentes
    BEGIN
      SELECT NVL(SUM(DECODE(DAT.TIP_DATO, 'RECHAZADO', DAT.CANTIDAD, 0)), 0) CHE_RECHAZADO,
             NVL(SUM(DECODE(DAT.TIP_DATO, 'RECHAZADO_HISTORICO', DAT.CANTIDAD, 0)), 0) CHE_REC_HIST,
             NVL(SUM(DECODE(DAT.TIP_DATO, 'INH_HIST', DAT.CANTIDAD, 0)), 0) INH_HIST,
             NVL(SUM(DECODE(DAT.TIP_DATO, 'INH_ACT', DAT.CANTIDAD, 0)), 0) INH_ACT
      INTO V_CHE_RECHAZADOS,
           V_CHE_REC_HISTORICOS,
           V_INH_HISTORICAS,
           V_INHIBICIONES
      FROM (SELECT T.TIP_CHEQUE TIP_DATO, COUNT(*) CANTIDAD
            FROM GE_EQF_CHK_CHEQUES T
            WHERE T.NRO_SOLICITUD = G_NRO_SOLICITUD
            GROUP BY T.TIP_CHEQUE
            UNION ALL
            SELECT DECODE(T.IND_HISTORICO, 'S', 'INH_HIST', 'INH_ACT'),
                   COUNT(*) CANTIDAD
            FROM GE_EQF_CHK_INHABILITACIONES T
            WHERE T.NRO_SOLICITUD = G_NRO_SOLICITUD
            GROUP BY T.IND_HISTORICO) DAT;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        G_MSG_ERROR := G_MSG_ERROR ||
                       ' -No se encuentran datos de infocheck';
        RAISE G_ERROR;
      WHEN OTHERS THEN
        G_MSG_ERROR := G_MSG_ERROR ||
                       ' -Error al buscar datos de infocheck: ' || SQLERRM;
        RAISE G_ERROR;
    END;
  
    IF V_CHE_RECHAZADOS = 0
       AND V_CHE_REC_HISTORICOS = 0
       AND V_INHIBICIONES = 0
       AND V_INH_HISTORICAS = 0 THEN
      V_SIT_INFOCHEK := 1;
    ELSIF V_INHIBICIONES != 0 THEN
      V_SIT_INFOCHEK := 3;
    ELSIF V_INH_HISTORICAS != 0
          AND V_INHIBICIONES = 0 THEN
      V_SIT_INFOCHEK := 2;
    ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) IN (1, 2, 3) THEN
      V_SIT_INFOCHEK := 4;
    ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) IN (4, 5, 6) THEN
      V_SIT_INFOCHEK := 5;
    ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) >= 7 THEN
      V_SIT_INFOCHEK := 6;
    END IF;
  
    IF FU_VER_REG_ANTECEDENTES(P_COD_PERSONA) THEN
      UPDATE GE_CLI_ANTECEDENTES A
      SET A.SIT_INFOCHECK     = V_SIT_INFOCHEK,
          A.FEC_ULT_INFOCHECK = G_FEC_ACTUAL
      WHERE A.COD_PERSONA = P_COD_PERSONA;
    ELSE
      INSERT INTO GE_CLI_ANTECEDENTES
        (COD_PERSONA, SIT_INFOCHECK, FEC_ULT_INFOCHECK)
      VALUES
        (P_COD_PERSONA, V_SIT_INFOCHEK, G_FEC_ACTUAL);
    END IF;
  
  END;

  FUNCTION FU_OBT_DAT_INFOCHECK(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS
    V_SIT_INFOCHEK       GE_CLI_ANTECEDENTES.SIT_INFOCHECK%TYPE;
    V_NRO_DOCUMENTO      BA_PERSONAS.NRO_DOCUMENTO%TYPE;
    V_RESPUESTA          VARCHAR2(4000);
    V_RETORNO            VARCHAR2(2);
    V_CHE_RECHAZADOS     VARCHAR2(3);
    V_CHE_REC_HISTORICOS VARCHAR2(3);
    --v_che_anulados       VARCHAR2(3); --no se tiene en cuenta
    V_INHIBICIONES   VARCHAR2(3);
    V_INH_HISTORICAS VARCHAR2(3);
    --v_con_historicas     VARCHAR2(3); --no se tiene en cuenta
    V_PAR_INGRESO VARCHAR2(22);
    V_OK          VARCHAR2(1); -- indica si el socket se corto o no
    V_FEC_ACTUAL  DATE := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
    -- -- -- -- -- -- --
    --Obtengo Valor para campo Sit_Infochek
    FUNCTION FL_OBT_COD_INFOCHECK RETURN VARCHAR2 IS
    BEGIN
      IF V_CHE_RECHAZADOS = 0
         AND V_CHE_REC_HISTORICOS = 0
         AND V_INHIBICIONES = 0
         AND V_INH_HISTORICAS = 0 THEN
        RETURN 1;
      ELSIF V_INHIBICIONES != 0 THEN
        RETURN 3;
      ELSIF V_INH_HISTORICAS != 0
            AND V_INHIBICIONES = 0 THEN
        RETURN 2;
      ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) IN (1, 2, 3) THEN
        RETURN 4;
      ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) IN (4, 5, 6) THEN
        RETURN 5;
      ELSIF (V_CHE_RECHAZADOS + V_CHE_REC_HISTORICOS) >= 7 THEN
        RETURN 6;
      END IF;
    END;
  BEGIN
    V_NRO_DOCUMENTO := FUE_OBT_NRO_DOC_PERSONA(P_COD_PERSONA);
    V_PAR_INGRESO   := '01' || LPAD(V_NRO_DOCUMENTO, 15, ' ');
    --llama a socket
    V_OK := FUE_ENV_TCP_MENSAJES(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
    --v_ok        := 'S';
    V_RESPUESTA := '0000000000000';
    IF V_OK != 'S' THEN
      PR_ERR_MENSAJES('Error con el Socket Infocheck.');
    ELSE
      V_RETORNO := SUBSTR(V_RESPUESTA, 1, 2);
      IF V_RETORNO != '00' THEN
        --El codigo 12 es Cliente No Encontrado, igual se actualiza la fecha y asigna 1 por defecto para enviar al motor
        IF V_RETORNO = '12' THEN
          IF FU_VER_REG_ANTECEDENTES(P_COD_PERSONA) THEN
            UPDATE GE_CLI_ANTECEDENTES A
            SET A.FEC_ULT_INFOCHECK = V_FEC_ACTUAL, A.SIT_INFOCHECK = 1
            WHERE A.COD_PERSONA = P_COD_PERSONA;
          ELSE
            INSERT INTO GE_CLI_ANTECEDENTES
              (COD_PERSONA, FEC_ULT_INFOCHECK, SIT_INFOCHECK)
            VALUES
              (P_COD_PERSONA, V_FEC_ACTUAL, 1);
          END IF;
        END IF;
        --error en la conexion
        RETURN 'Infocheck => ' || SUBSTR(V_RESPUESTA, 1, 2) || ' ' || SUBSTR(V_RESPUESTA, 3, LENGTH(V_RESPUESTA));
      ELSE
        V_CHE_RECHAZADOS     := TO_NUMBER(SUBSTR(V_RESPUESTA, 3, 3));
        V_CHE_REC_HISTORICOS := TO_NUMBER(SUBSTR(V_RESPUESTA, 6, 3));
        --v_che_anulados     := to_number(substr(v_respuesta, 9, 3));
        V_INHIBICIONES   := TO_NUMBER(SUBSTR(V_RESPUESTA, 12, 3));
        V_INH_HISTORICAS := TO_NUMBER(SUBSTR(V_RESPUESTA, 15, 3));
        --v_con_historicas     := to_number(substr(v_respuesta, 18, 3));
        --v_sit_infochek := fl_obt_cod_infocheck;
        SELECT TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 6)))
        INTO V_SIT_INFOCHEK
        FROM DUAL;
        IF FU_VER_REG_ANTECEDENTES(P_COD_PERSONA) THEN
          UPDATE GE_CLI_ANTECEDENTES A
          SET A.SIT_INFOCHECK     = V_SIT_INFOCHEK,
              A.FEC_ULT_INFOCHECK = V_FEC_ACTUAL
          WHERE A.COD_PERSONA = P_COD_PERSONA;
        ELSE
          INSERT INTO GE_CLI_ANTECEDENTES
            (COD_PERSONA, SIT_INFOCHECK, FEC_ULT_INFOCHECK)
          VALUES
            (P_COD_PERSONA, V_SIT_INFOCHEK, V_FEC_ACTUAL);
        END IF;
        RETURN 'Infocheck => OK';
      END IF;
    END IF;
  END;

  PROCEDURE PR_PRO_XML_SCORING(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                               P_XMLRESPUESTA   IN XMLTYPE,
                               P_PRO_INDIVIDUAL IN VARCHAR2,
                               P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_FAJ_SCORING := NULL;
  
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(1, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH || 'faja/text()') FAJA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'probabilidadInicial/text()') PROBABILIDADINICIAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'probabilidadFinal/text()') PROBABILIDADFINAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'rangoScoreInicial/text()') RANGOSCOREINICIAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'rangoScoreFinal/text()') RANGOSCOREFINAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_FAJ_SCORING T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_FAJ_SCORING.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_FAJ_SCORING.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_FAJ_SCORING.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_FAJ_SCORING.USU_INSERCION      := USER;
        R_GE_EQF_FAJ_SCORING.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_FAJ_SCORING.USU_MODIFICACION   := USER;
        R_GE_EQF_FAJ_SCORING.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_FAJ_SCORING.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_FAJ_SCORING.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_FAJ_SCORING.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_FAJ_SCORING.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                   R.MENSAJE_ERROR;
      
        BEGIN
          INSERT INTO GE_EQF_FAJ_SCORING
          VALUES R_GE_EQF_FAJ_SCORING;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_FAJ_SCORING.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_FAJ_SCORING.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_FAJ_SCORING.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_FAJ_SCORING.USU_INSERCION      := USER;
        R_GE_EQF_FAJ_SCORING.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_FAJ_SCORING.USU_MODIFICACION   := USER;
        R_GE_EQF_FAJ_SCORING.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_FAJ_SCORING.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_FAJ_SCORING.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_FAJ_SCORING.NRO_SECUENCIA      := G_NRO_SECUENCIA;
      
        R_GE_EQF_FAJ_SCORING.FAJA            := R.FAJA;
        R_GE_EQF_FAJ_SCORING.PRO_INICIAL     := R.PROBABILIDADINICIAL;
        R_GE_EQF_FAJ_SCORING.PRO_FINAL       := R.PROBABILIDADFINAL;
        R_GE_EQF_FAJ_SCORING.RAN_SCO_INICIAL := R.RANGOSCOREINICIAL;
        R_GE_EQF_FAJ_SCORING.RAN_SCO_FINAL   := R.RANGOSCOREFINAL;
      
        BEGIN
          INSERT INTO GE_EQF_FAJ_SCORING
          VALUES R_GE_EQF_FAJ_SCORING;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      
        --actualiza en la tabla ge_cli_antecedentes (Faj_buro y fec_ult_inf)
        IF FU_VER_REG_ANTECEDENTES(PI_COD_PERSONA) THEN
          BEGIN
            UPDATE GE_CLI_ANTECEDENTES T
            SET T.FAJ_BURO = R.FAJA, T.FEC_ULT_INFORMCONF = G_FEC_ACTUAL
            WHERE T.COD_PERSONA = PI_COD_PERSONA;
          
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL;
            WHEN OTHERS THEN
              G_MSG_ERROR := G_MSG_ERROR ||
                             ' -Error al actualizar datos de ' || G_PROCESO ||
                             ' en antecedentes: ' || SQLERRM;
              RAISE G_ERROR;
          END;
        ELSE
          INSERT INTO GE_CLI_ANTECEDENTES
            (COD_PERSONA, FAJ_BURO, FEC_ULT_INFORMCONF)
          VALUES
            (PI_COD_PERSONA, R.FAJA, G_FEC_ACTUAL);
        END IF;
      
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_CONVOCATORIA_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                        P_XMLRESPUESTA   IN XMLTYPE,
                                        P_PRO_INDIVIDUAL IN VARCHAR2,
                                        P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_CONVOCATORIA_RES := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(2, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadNoFiniquitadas/text()') CANT_NO_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadSiFiniquitadas/text()') CANT_SI_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFecha/text()') MENOR_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFecha/text()') MAYOR_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_CONVOCATORIAS_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_CONVOCATORIA_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CONVOCATORIA_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CONVOCATORIA_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CONVOCATORIA_RES.USU_INSERCION      := USER;
        R_GE_EQF_CONVOCATORIA_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CONVOCATORIA_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_CONVOCATORIA_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CONVOCATORIA_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CONVOCATORIA_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CONVOCATORIA_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CONVOCATORIA_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                        R.MENSAJE_ERROR;
        R_GE_EQF_CONVOCATORIA_RES.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_CONVOCATORIAS_RES
          VALUES R_GE_EQF_CONVOCATORIA_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_CONVOCATORIA_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CONVOCATORIA_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CONVOCATORIA_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CONVOCATORIA_RES.USU_INSERCION      := USER;
        R_GE_EQF_CONVOCATORIA_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CONVOCATORIA_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_CONVOCATORIA_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CONVOCATORIA_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CONVOCATORIA_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CONVOCATORIA_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CONVOCATORIA_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_CONVOCATORIA_RES.CAN_TOTAL           := R.CANT_TOTAL;
        R_GE_EQF_CONVOCATORIA_RES.CAN_FINIQUITADAS    := R.CANT_SI_FINIQ;
        R_GE_EQF_CONVOCATORIA_RES.CAN_NO_FINIQUITADAS := R.CANT_NO_FINIQ;
        R_GE_EQF_CONVOCATORIA_RES.MAY_FEC_ADMISION    := R.MAYOR_FECHA;
        R_GE_EQF_CONVOCATORIA_RES.MEN_FEC_ADMISION    := R.MENOR_FECHA;
      
        BEGIN
          INSERT INTO GE_EQF_CONVOCATORIAS_RES
          VALUES R_GE_EQF_CONVOCATORIA_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_DEMANDA_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_XMLRESPUESTA   IN XMLTYPE,
                                   P_PRO_INDIVIDUAL IN VARCHAR2,
                                   P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_DEMANDA_RES := NULL;
  
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(3, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadNoFiniquitadas/text()') CANT_NO_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadSiFiniquitadas/text()') CANT_SI_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaSiFiniquitada/text()') MENOR_FEC_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaSiFiniquitada/text()') MAYOR_FEC_FINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaNoFiniquitada/text()') MENOR_FEC_NOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaNoFiniquitada/text()') MAYOR_FEC_NOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_DEMANDAS_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_DEMANDA_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_DEMANDA_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_DEMANDA_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_DEMANDA_RES.USU_INSERCION      := USER;
        R_GE_EQF_DEMANDA_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_DEMANDA_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_DEMANDA_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_DEMANDA_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_DEMANDA_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_DEMANDA_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_DEMANDA_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                   R.MENSAJE_ERROR;
        R_GE_EQF_DEMANDA_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        BEGIN
          INSERT INTO GE_EQF_DEMANDAS_RES
          VALUES R_GE_EQF_DEMANDA_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_DEMANDA_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_DEMANDA_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_DEMANDA_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_DEMANDA_RES.USU_INSERCION      := USER;
        R_GE_EQF_DEMANDA_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_DEMANDA_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_DEMANDA_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_DEMANDA_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_DEMANDA_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_DEMANDA_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_DEMANDA_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_DEMANDA_RES.CAN_TOTAL                   := R.CANT_TOTAL;
        R_GE_EQF_DEMANDA_RES.CAN_NO_FINIQUITADAS         := R.CANT_NO_FINIQ;
        R_GE_EQF_DEMANDA_RES.CAN_FINIQUITADAS            := R.CANT_SI_FINIQ;
        R_GE_EQF_DEMANDA_RES.MEN_FEC_DEM_FINIQUITADAS    := R.MENOR_FEC_FINIQ;
        R_GE_EQF_DEMANDA_RES.MAY_FEC_DEM_FINIQUITADAS    := R.MAYOR_FEC_FINIQ;
        R_GE_EQF_DEMANDA_RES.MEN_FEC_DEM_NO_FINIQUITADAS := R.MENOR_FEC_NOFINIQ;
        R_GE_EQF_DEMANDA_RES.MAY_FEC_DEM_NO_FINIQUITADAS := R.MAYOR_FEC_NOFINIQ;
      
        BEGIN
          INSERT INTO GE_EQF_DEMANDAS_RES
          VALUES R_GE_EQF_DEMANDA_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_INHABILITACIO_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                         P_XMLRESPUESTA   IN XMLTYPE,
                                         P_PRO_INDIVIDUAL IN VARCHAR2,
                                         P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_INHABILITACIONES_RES := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(4, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFecha/text()') MENORFECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFecha/text()') MAYORFECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorPlazoInhabilitacion/text()') MAYORPLAZO,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_INHABILITACIONES_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_INHABILITACIONES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_INHABILITACIONES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_INHABILITACIONES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_INHABILITACIONES_RES.USU_INSERCION      := USER;
        R_GE_EQF_INHABILITACIONES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_INHABILITACIONES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_INHABILITACIONES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_INHABILITACIONES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_INHABILITACIONES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_INHABILITACIONES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_INHABILITACIONES_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                            R.MENSAJE_ERROR;
        R_GE_EQF_INHABILITACIONES_RES.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_INHABILITACIONES_RES
          VALUES R_GE_EQF_INHABILITACIONES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_INHABILITACIONES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_INHABILITACIONES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_INHABILITACIONES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_INHABILITACIONES_RES.USU_INSERCION      := USER;
        R_GE_EQF_INHABILITACIONES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_INHABILITACIONES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_INHABILITACIONES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_INHABILITACIONES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_INHABILITACIONES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_INHABILITACIONES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_INHABILITACIONES_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_INHABILITACIONES_RES.CAN_TOTAL              := R.CANT_TOTAL;
        R_GE_EQF_INHABILITACIONES_RES.MEN_FEC_INHABILITACION := R.MENORFECHA;
        R_GE_EQF_INHABILITACIONES_RES.MAY_FEC_INHABILITACION := R.MAYORFECHA;
        R_GE_EQF_INHABILITACIONES_RES.MAY_PLZ_INHABILITACION := R.MAYORPLAZO;
      
        BEGIN
          INSERT INTO GE_EQF_INHABILITACIONES_RES
          VALUES R_GE_EQF_INHABILITACIONES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_INHIBICIONES_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                        P_XMLRESPUESTA   IN XMLTYPE,
                                        P_PRO_INDIVIDUAL IN VARCHAR2,
                                        P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_INHIBICIONES_RES := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(5, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadNoFiniquitadas/text()') CANT_NOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadSiFiniquitadas/text()') CANT_SIFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaNoFiniquitada/text()') MEN_FECNOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaNoFiniquitada/text()') MAY_FECNOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaSiFiniquitada/text()') MEN_FECSIFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaSiFiniquitada/text()') MAY_FECSIFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_INHIBICIONES_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_INHIBICIONES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_INHIBICIONES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_INHIBICIONES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_INHIBICIONES_RES.USU_INSERCION      := USER;
        R_GE_EQF_INHIBICIONES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_INHIBICIONES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_INHIBICIONES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_INHIBICIONES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_INHIBICIONES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_INHIBICIONES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_INHIBICIONES_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                        R.MENSAJE_ERROR;
        R_GE_EQF_INHIBICIONES_RES.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_INHIBICIONES_RES
          VALUES R_GE_EQF_INHIBICIONES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_INHIBICIONES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_INHIBICIONES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_INHIBICIONES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_INHIBICIONES_RES.USU_INSERCION      := USER;
        R_GE_EQF_INHIBICIONES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_INHIBICIONES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_INHIBICIONES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_INHIBICIONES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_INHIBICIONES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_INHIBICIONES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_INHIBICIONES_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_INHIBICIONES_RES.CAN_TOTAL                   := R.CANT_TOTAL;
        R_GE_EQF_INHIBICIONES_RES.CAN_NO_FINIQUITADAS         := R.CANT_NOFINIQ;
        R_GE_EQF_INHIBICIONES_RES.CAN_FINIQUITADAS            := R.CANT_SIFINIQ;
        R_GE_EQF_INHIBICIONES_RES.MAY_FEC_INH_FINIQUITADAS    := R.MAY_FECSIFINIQ;
        R_GE_EQF_INHIBICIONES_RES.MEN_FEC_INH_FINIQUITADAS    := R.MEN_FECSIFINIQ;
        R_GE_EQF_INHIBICIONES_RES.MAY_FEC_INH_NO_FINIQUITADAS := R.MAY_FECNOFINIQ;
        R_GE_EQF_INHIBICIONES_RES.MEN_FEC_INH_NO_FINIQUITADAS := R.MEN_FECNOFINIQ;
      
        BEGIN
          INSERT INTO GE_EQF_INHIBICIONES_RES
          VALUES R_GE_EQF_INHIBICIONES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_MOR_ACT_ADEFI(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                     P_XMLRESPUESTA   IN XMLTYPE,
                                     P_PRO_INDIVIDUAL IN VARCHAR2,
                                     P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_MOR_ACT_ADEFI := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(6, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'actividadAfiliado/text()') ACT_AFIL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaVencimientoPendiente/text()') MAY_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaVencimientoPendiente/text()') MEN_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH || 'moneda/text()') MONEDA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'sumaSaldoAcreedor/text()') SALDO_ACREEDOR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_MOR_ACT_ADEFI T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_MOR_ACT_ADEFI.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_MOR_ACT_ADEFI.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_MOR_ACT_ADEFI.USU_INSERCION      := USER;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_MOR_ACT_ADEFI.USU_MODIFICACION   := USER;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_MOR_ACT_ADEFI.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_MOR_ACT_ADEFI.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_MOR_ACT_ADEFI.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_MOR_ACT_ADEFI.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                     R.MENSAJE_ERROR;
        R_GE_EQF_MOR_ACT_ADEFI.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_MOR_ACT_ADEFI
          VALUES R_GE_EQF_MOR_ACT_ADEFI;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_MOR_ACT_ADEFI.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_MOR_ACT_ADEFI.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_MOR_ACT_ADEFI.USU_INSERCION      := USER;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_MOR_ACT_ADEFI.USU_MODIFICACION   := USER;
        R_GE_EQF_MOR_ACT_ADEFI.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_MOR_ACT_ADEFI.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_MOR_ACT_ADEFI.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_MOR_ACT_ADEFI.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_MOR_ACT_ADEFI.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_MOR_ACT_ADEFI.ACT_AFILIADO          := R.ACT_AFIL;
        R_GE_EQF_MOR_ACT_ADEFI.CANTIDAD              := R.CANT_TOTAL;
        R_GE_EQF_MOR_ACT_ADEFI.MAY_FEC_VTO_PENDIENTE := R.MAY_FECHA;
        R_GE_EQF_MOR_ACT_ADEFI.MEN_FEC_VTO_PENDIENTE := R.MEN_FECHA;
        R_GE_EQF_MOR_ACT_ADEFI.MONEDA                := R.MONEDA;
        R_GE_EQF_MOR_ACT_ADEFI.SUM_SAL_ACREEDOR      := R.SALDO_ACREEDOR;
      
        BEGIN
          INSERT INTO GE_EQF_MOR_ACT_ADEFI
          VALUES R_GE_EQF_MOR_ACT_ADEFI;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_MOR_ACTIVIDAD(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                     P_XMLRESPUESTA   IN XMLTYPE,
                                     P_PRO_INDIVIDUAL IN VARCHAR2,
                                     P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_MOR_ACTIVIDAD := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(7, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'actividadAfiliado/text()') ACT_AFIL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFechaVencimientoPendiente/text()') MAY_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFechaVencimientoPendiente/text()') MEN_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH || 'moneda/text()') MONEDA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'sumaSaldoAcreedor/text()') SALDO_ACREEDOR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_MOR_ACTIVIDADES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_MOR_ACTIVIDAD.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_MOR_ACTIVIDAD.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_MOR_ACTIVIDAD.USU_INSERCION      := USER;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_MOR_ACTIVIDAD.USU_MODIFICACION   := USER;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_MOR_ACTIVIDAD.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_MOR_ACTIVIDAD.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_MOR_ACTIVIDAD.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_MOR_ACTIVIDAD.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                     R.MENSAJE_ERROR;
        R_GE_EQF_MOR_ACTIVIDAD.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_MOR_ACTIVIDADES
          VALUES R_GE_EQF_MOR_ACTIVIDAD;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_MOR_ACTIVIDAD.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_MOR_ACTIVIDAD.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_MOR_ACTIVIDAD.USU_INSERCION      := USER;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_MOR_ACTIVIDAD.USU_MODIFICACION   := USER;
        R_GE_EQF_MOR_ACTIVIDAD.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_MOR_ACTIVIDAD.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_MOR_ACTIVIDAD.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_MOR_ACTIVIDAD.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_MOR_ACTIVIDAD.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_MOR_ACTIVIDAD.ACT_AFILIADO          := R.ACT_AFIL;
        R_GE_EQF_MOR_ACTIVIDAD.CANTIDAD              := R.CANT_TOTAL;
        R_GE_EQF_MOR_ACTIVIDAD.MAY_FEC_VTO_PENDIENTE := R.MAY_FECHA;
        R_GE_EQF_MOR_ACTIVIDAD.MEN_FEC_VTO_PENDIENTE := R.MEN_FECHA;
        R_GE_EQF_MOR_ACTIVIDAD.MONEDA                := R.MONEDA;
        R_GE_EQF_MOR_ACTIVIDAD.SUM_SAL_ACREEDOR      := R.SALDO_ACREEDOR;
      
        BEGIN
          INSERT INTO GE_EQF_MOR_ACTIVIDADES
          VALUES R_GE_EQF_MOR_ACTIVIDAD;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_REMATES_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_XMLRESPUESTA   IN XMLTYPE,
                                   P_PRO_INDIVIDUAL IN VARCHAR2,
                                   P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_REMATES_RES := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(8, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadNoFiniquitadas/text()') CANT_NOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadSiFiniquitadas/text()') CANT_SIFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFecha/text()') MEN_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFecha/text()') MAY_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_REMATES_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_REMATES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_REMATES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_REMATES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_REMATES_RES.USU_INSERCION      := USER;
        R_GE_EQF_REMATES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_REMATES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_REMATES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_REMATES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_REMATES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_REMATES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_REMATES_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                   R.MENSAJE_ERROR;
        R_GE_EQF_REMATES_RES.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_REMATES_RES
          VALUES R_GE_EQF_REMATES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_REMATES_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_REMATES_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_REMATES_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_REMATES_RES.USU_INSERCION      := USER;
        R_GE_EQF_REMATES_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_REMATES_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_REMATES_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_REMATES_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_REMATES_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_REMATES_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_REMATES_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_REMATES_RES.CAN_TOTAL           := R.CANT_TOTAL;
        R_GE_EQF_REMATES_RES.CAN_FINIQUITADAS    := R.CANT_SIFINIQ;
        R_GE_EQF_REMATES_RES.CAN_NO_FINIQUITADAS := R.CANT_NOFINIQ;
        R_GE_EQF_REMATES_RES.MEN_FEC_REMATE      := R.MEN_FECHA;
        R_GE_EQF_REMATES_RES.MAY_FEC_REMATE      := R.MAY_FECHA;
      
        BEGIN
          INSERT INTO GE_EQF_REMATES_RES
          VALUES R_GE_EQF_REMATES_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_SOL_DETALLE(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_XMLRESPUESTA   IN XMLTYPE,
                                   P_PRO_INDIVIDUAL IN VARCHAR2,
                                   P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_SOL_DETALLE := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(9, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH || 'nombre/text()') NOMBRE,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH || 'fecha/text()') FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'telefono/text()') TEL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'tipoOperacion/text()') TIP_OPERACION,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_SOL_DETALLES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_SOL_DETALLE.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_SOL_DETALLE.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_SOL_DETALLE.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_SOL_DETALLE.USU_INSERCION      := USER;
        R_GE_EQF_SOL_DETALLE.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_SOL_DETALLE.USU_MODIFICACION   := USER;
        R_GE_EQF_SOL_DETALLE.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_SOL_DETALLE.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_SOL_DETALLE.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_SOL_DETALLE.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_SOL_DETALLE.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                   R.MENSAJE_ERROR;
        R_GE_EQF_SOL_DETALLE.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_SOL_DETALLES
          VALUES R_GE_EQF_SOL_DETALLE;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_SOL_DETALLE.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_SOL_DETALLE.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_SOL_DETALLE.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_SOL_DETALLE.USU_INSERCION      := USER;
        R_GE_EQF_SOL_DETALLE.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_SOL_DETALLE.USU_MODIFICACION   := USER;
        R_GE_EQF_SOL_DETALLE.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_SOL_DETALLE.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_SOL_DETALLE.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_SOL_DETALLE.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_SOL_DETALLE.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_SOL_DETALLE.NOMBRE          := R.NOMBRE;
        R_GE_EQF_SOL_DETALLE.FECHA           := R.FECHA;
        R_GE_EQF_SOL_DETALLE.TELEFONO        := R.TEL;
        R_GE_EQF_SOL_DETALLE.TIP_OPERACIONES := R.TIP_OPERACION;
      
        BEGIN
          INSERT INTO GE_EQF_SOL_DETALLES
          VALUES R_GE_EQF_SOL_DETALLE;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_QUIEBRAS_RES(PI_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                    P_XMLRESPUESTA   IN XMLTYPE,
                                    P_PRO_INDIVIDUAL IN VARCHAR2,
                                    P_MENSAJE        OUT VARCHAR2) IS
    V_XML_COL_PATH     VARCHAR2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
  
  BEGIN
    R_GE_EQF_QUIEBRAS_RES := NULL;
    --si es un proceso completo se vuelve a obtener los datos del servicio
    IF G_IND_REINTENTO = 'N' THEN
      --se obtiene el parámetro de envío y el nombre del servicio
      PR_OBT_PAR_SER_INFORMCONF(10, G_PAR_ENVIO, G_NOM_SERVICIO);
    END IF;
  
    G_PROCESO       := G_NOM_SERVICIO;
    G_NRO_SECUENCIA := 0;
  
    --de acuerdo al proceso individual o no se establece el path de columnas xml
    IF P_PRO_INDIVIDUAL = 'S' THEN
      V_XML_COL_PATH     := 'ServResponse/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    ELSIF P_PRO_INDIVIDUAL = 'N' THEN
      V_XML_COL_PATH     := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/data/';
      V_XML_COL_ERR_PATH := 'ServResponse/data/' || G_NOM_SERVICIO ||
                            '/error/';
    END IF;
  
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadTotal/text()') CANT_TOTAL,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadNoFiniquitadas/text()') CANT_NOFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'cantidadSiFiniquitadas/text()') CANT_SIFINIQ,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'menorFecha/text()') MEN_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_PATH ||
                                   'mayorFecha/text()') MAY_FECHA,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'code/text()') AS COD_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'externalCode/text()') AS COD_EXT_ERROR,
                     EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                                   'message/text()') AS MENSAJE_ERROR
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      --SE ELIMINA EL ÚLTIMO REGISTRO CON ERROR
      IF G_IND_REINTENTO = 'S' THEN
        DELETE GE_EQF_QUIEBRAS_RES T
        WHERE T.COD_PERSONA = PI_COD_PERSONA
        AND T.NRO_SOLICITUD = G_NRO_SOLICITUD
        AND T.MSG_ERROR IS NOT NULL;
      
      END IF;
      --SI TIENE ERROR LA RESPUESTA
      IF R.COD_ERROR IS NOT NULL THEN
        R_GE_EQF_QUIEBRAS_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_QUIEBRAS_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_QUIEBRAS_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_QUIEBRAS_RES.USU_INSERCION      := USER;
        R_GE_EQF_QUIEBRAS_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_QUIEBRAS_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_QUIEBRAS_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_QUIEBRAS_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_QUIEBRAS_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_QUIEBRAS_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_QUIEBRAS_RES.MSG_ERROR          := '[REINTENTAR] - ERROR:' ||
                                                    R.MENSAJE_ERROR;
        R_GE_EQF_QUIEBRAS_RES.TIP_PERSONA        := G_TIP_PERSONA;
        BEGIN
          INSERT INTO GE_EQF_QUIEBRAS_RES
          VALUES R_GE_EQF_QUIEBRAS_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE     := G_PROCESO || ' actualizado con errores';
        G_ACU_ERRORES := G_ACU_ERRORES + 1;
        --SIN ERRORES
      ELSE
      
        R_GE_EQF_QUIEBRAS_RES.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_QUIEBRAS_RES.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_QUIEBRAS_RES.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_QUIEBRAS_RES.USU_INSERCION      := USER;
        R_GE_EQF_QUIEBRAS_RES.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_QUIEBRAS_RES.USU_MODIFICACION   := USER;
        R_GE_EQF_QUIEBRAS_RES.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_QUIEBRAS_RES.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_QUIEBRAS_RES.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_QUIEBRAS_RES.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_QUIEBRAS_RES.TIP_PERSONA        := G_TIP_PERSONA;
      
        R_GE_EQF_QUIEBRAS_RES.CAN_TOTAL           := R.CANT_TOTAL;
        R_GE_EQF_QUIEBRAS_RES.CAN_FINIQUITADAS    := R.CANT_SIFINIQ;
        R_GE_EQF_QUIEBRAS_RES.CAN_NO_FINIQUITADAS := R.CANT_NOFINIQ;
        R_GE_EQF_QUIEBRAS_RES.MEN_FEC_QUIEBRA     := R.MEN_FECHA;
        R_GE_EQF_QUIEBRAS_RES.MEN_FEC_QUIEBRA     := R.MAY_FECHA;
      
        BEGIN
          INSERT INTO GE_EQF_QUIEBRAS_RES
          VALUES R_GE_EQF_QUIEBRAS_RES;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
        P_MENSAJE := G_PROCESO || ' actualizado';
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al procesar datos de ' ||
                     G_PROCESO || ': ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_REPORTE_PDF(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_XMLRESPUESTA IN XMLTYPE
                                   --,P_PRO_INDIVIDUAL in varchar2
                                  ,
                                   P_MENSAJE OUT VARCHAR2) IS
    --V_XML_COL_PATH     varchar2(200);
    V_XML_COL_ERR_PATH VARCHAR2(200);
    V_PAR_INGRESO      VARCHAR2(500);
    V_RESPUESTA        CLOB;
    V_OK               VARCHAR2(1); -- indica si el socket se corto o no
    XMLRESPUESTA       XMLTYPE;
    V_CON_ERROR        VARCHAR2(5) := 'N';
  
  BEGIN
  
    IF G_TIP_SERVICIO != 11 THEN
      PR_OBT_PAR_SER_INFORMCONF(11, G_PAR_ENVIO, G_NOM_SERVICIO);
    
      IF G_TIP_PERSONA = 'F' THEN
        G_TIP_PERSONA := 'PE';
      ELSIF G_TIP_PERSONA = 'J' THEN
        G_TIP_PERSONA := 'EM';
        G_PAR_ENVIO   := '#REP_B#'; --PARÁMETRO DE LLAMADA PARA REPORTES DE EMPRESA
      END IF;
      --mensaje para el socket de tipo servicio nuevo
    
      V_PAR_INGRESO := G_TIP_PERSONA || G_PAR_ENVIO || G_NRO_DOCUMENTO;
    
      V_OK := FU_ENV_TCP_MSJCLOB(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
    
      --Control de errores
      IF V_OK != 'S' THEN
      
        G_MSG_ERROR := G_MSG_ERROR || ' -Error con el Socket Informconf.c' ||
                       V_RESPUESTA;
        RAISE G_ERROR;
      ELSE
        XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
        FOR R IN (SELECT EXTRACTVALUE(VALUE(P), 'ServResponse/Status/text()') AS STATUS,
                         EXTRACTVALUE(VALUE(P), 'ServResponse/error/code/text()') AS COD_ERROR,
                         EXTRACTVALUE(VALUE(P), 'ServResponse/error/externalCode/text()') AS COD_EXT_ERROR,
                         EXTRACTVALUE(VALUE(P), 'ServResponse/error/message/text()') AS MENSAJE_ERROR
                  FROM TABLE(XMLSEQUENCE(EXTRACT(XMLRESPUESTA, '/ServResponse'))) P)
        LOOP
          IF R.STATUS != 'OK' THEN
            G_MSG_ERROR := G_MSG_ERROR || 'Error: cod error:' ||
                           R.COD_ERROR || ' cod externo:' ||
                           R.COD_EXT_ERROR || ' mensaje:' ||
                           R.MENSAJE_ERROR;
          
            G_ACU_ERRORES := G_ACU_ERRORES + 1;
            V_CON_ERROR   := 'S';
          
            --actualizamos la solicitud con el nombre de reporte generado
            BEGIN
              UPDATE GE_EQF_SOLICITUDES T
              SET T.MSG_ERROR = '[REINTENTAR] - ERROR:' || R.MENSAJE_ERROR
              WHERE T.NRO_SOLICITUD = G_NRO_SOLICITUD;
            END;
          
          END IF;
        END LOOP;
      END IF;
      XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
    ELSE
      XMLRESPUESTA := P_XMLRESPUESTA;
    END IF;
    IF V_CON_ERROR = 'N' THEN
      G_PROCESO       := G_NOM_SERVICIO;
      G_NRO_SECUENCIA := 0;
      XMLRESPUESTA    := XMLTYPE(V_RESPUESTA);
    
      V_XML_COL_ERR_PATH := 'ServResponse/error/';
    
      FOR R IN (SELECT /*EXTRACTVALUE(value(P), V_XML_COL_PATH || 'reportePdfBase64/Clob()') REPORTE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ,*/
                 EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH || 'code/text()') AS COD_ERROR,
                 EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                               'externalCode/text()') AS COD_EXT_ERROR,
                 EXTRACTVALUE(VALUE(P), V_XML_COL_ERR_PATH ||
                               'message/text()') AS MENSAJE_ERROR
                
                FROM TABLE(XMLSEQUENCE(EXTRACT(XMLRESPUESTA, '/ServResponse'))) P)
      LOOP
      
        --SI TIENE ERROR LA RESPUESTA
        IF R.COD_ERROR IS NOT NULL THEN
        
          P_MENSAJE := '[REINTENTAR] - ERROR:' || R.MENSAJE_ERROR;
        
          G_ACU_ERRORES := G_ACU_ERRORES + 1;
        
        ELSE
          --SIN ERRORES
        
          BEGIN
            SELECT XT.REPORTE
            INTO V_REPORTE64
            FROM XMLTABLE('/ServResponse/data' PASSING XMLRESPUESTA COLUMNS
                          REPORTE CLOB PATH 'reportePdfBase64') XT;
          END;
        
          --V_REPORTE64  := R.REPORTE;
          V_REPORTEPDF     := FU_CLOB_TO_BLOB(FU_DEC_BASE64(V_REPORTE64));
          V_NOM_REPORTEPDF := FU_OBT_NOM_REPORTEPDF(PI_COD_PERSONA);
          PAG_EQF.PR_GEN_ARC_PDF(V_NOM_REPORTEPDF, 'MAIL', V_REPORTEPDF);
        
          V_RESPUESTA := PA_FILE_FTP.FU_PUT_BINARY(G_REP_ARC_SERVIDOR, G_REP_ARC_PORT, G_REP_ARC_USER, G_REP_ARC_PASS, G_DIR_DATABASE, V_NOM_REPORTEPDF, G_DIR_IFORMES_PDF ||
                                                    V_NOM_REPORTEPDF);
        
          IF V_RESPUESTA = 'OK' THEN
            --ARCHIVO ENVIADO POR FTP
            DBMS_OUTPUT.PUT_LINE('OK!!');
            P_MENSAJE := 'Archivo generado';
          ELSE
            DBMS_OUTPUT.PUT_LINE(SQLERRM);
            P_MENSAJE := 'Error al generar archivo: ' || V_RESPUESTA ||
                         ' - ' || SQLERRM;
          END IF;
        
          P_MENSAJE := ' PDF Generado';
        
          --actualizamos la solicitud con el nombre de reporte generado
          BEGIN
            UPDATE GE_EQF_SOLICITUDES T
            SET T.NOM_INFORME = V_NOM_REPORTEPDF
            WHERE T.NRO_SOLICITUD = G_NRO_SOLICITUD;
          END;
        
        END IF;
      
      END LOOP;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || 'Error al generar PDF: ' || SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_CHK_DAT_PERSONA(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                       P_XMLRESPUESTA IN XMLTYPE,
                                       P_MENSAJE      OUT VARCHAR2) IS
  
    V_PATH_DET_PERSONA VARCHAR2(500);
  BEGIN
    G_PROCESO                := 'Datos de persona';
    V_PATH_DET_PERSONA       := 'ServResponse/data/persona/detallePersona/';
    G_NRO_SECUENCIA          := 0;
    R_GE_EQF_CHK_DET_PERSONA := NULL;
    /*for C in (select XT.*
    from XMLTABLE(V_PATH_DET_PERSONA PASSING P_XMLRESPUESTA COLUMNS
                  --detalle Persona--
                  TIP_DOCUMENTO varchar2(100) PATH 'tipoDocumento',
                  NRO_DOCUMENTO varchar2(100) PATH 'documento',
                  NOMBRES varchar2(100) PATH 'nombres',
                  APELLIDOS varchar2(100) PATH 'apellidos',
                  FEC_NACIMIENTO varchar2(100) PATH 'fechaNacimiento',
                  SEXO varchar2(100) PATH 'sexo') XT) loop*/
  
    FOR C IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'tipoDocumento/text()') TIP_DOCUMENTO,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'documento/text()') NRO_DOCUMENTO,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'nombres/text()') NOMBRES,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'apellidos/text()') APELLIDOS,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'sexo/text()') SEXO,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'fechaNacimiento/text()') FEC_NACIMIENTO
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      R_GE_EQF_CHK_DET_PERSONA.COD_PERSONA        := PI_COD_PERSONA;
      R_GE_EQF_CHK_DET_PERSONA.FEC_CONSULTA       := G_FEC_ACTUAL;
      R_GE_EQF_CHK_DET_PERSONA.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      R_GE_EQF_CHK_DET_PERSONA.USU_INSERCION      := USER;
      R_GE_EQF_CHK_DET_PERSONA.FEC_INSERCION      := SYSDATE;
      R_GE_EQF_CHK_DET_PERSONA.USU_MODIFICACION   := USER;
      R_GE_EQF_CHK_DET_PERSONA.FEC_MODIFICACION   := SYSDATE;
      R_GE_EQF_CHK_DET_PERSONA.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
      R_GE_EQF_CHK_DET_PERSONA.NRO_SOLICITUD      := G_NRO_SOLICITUD;
      R_GE_EQF_CHK_DET_PERSONA.NRO_SECUENCIA      := G_NRO_SECUENCIA;
    
      R_GE_EQF_CHK_DET_PERSONA.TIP_DOCUMENTO  := C.TIP_DOCUMENTO;
      R_GE_EQF_CHK_DET_PERSONA.NRO_DOCUMENTO  := C.NRO_DOCUMENTO;
      R_GE_EQF_CHK_DET_PERSONA.NOMBRE         := C.NOMBRES;
      R_GE_EQF_CHK_DET_PERSONA.APELLIDO       := C.APELLIDOS;
      R_GE_EQF_CHK_DET_PERSONA.FEC_NACIMIENTO := C.FEC_NACIMIENTO;
      R_GE_EQF_CHK_DET_PERSONA.SEXO           := C.SEXO;
      --registro de datos
      BEGIN
        INSERT INTO GE_EQF_CHK_DET_PERSONAS
        VALUES R_GE_EQF_CHK_DET_PERSONA;
      EXCEPTION
        WHEN OTHERS THEN
          G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                         G_PROCESO || ': ' || SQLERRM;
          RAISE G_ERROR;
      END;
    
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_DAT_EMPRESA(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                       P_XMLRESPUESTA IN XMLTYPE,
                                       P_MENSAJE      OUT VARCHAR2) IS
  
    V_PATH_DET_PERSONA VARCHAR2(500);
  BEGIN
    G_PROCESO                := 'Datos de persona';
    V_PATH_DET_PERSONA       := 'ServResponse/data/persona/detallePersona/';
    G_NRO_SECUENCIA          := 0;
    R_GE_EQF_CHK_DET_PERSONA := NULL;
    /*for C in (select XT.*
    from XMLTABLE(V_PATH_DET_PERSONA PASSING P_XMLRESPUESTA COLUMNS
                  --detalle Persona--
                  TIP_DOCUMENTO varchar2(100) PATH 'tipoDocumento',
                  NRO_DOCUMENTO varchar2(100) PATH 'documento',
                  NOMBRES varchar2(100) PATH 'nombres',
                  APELLIDOS varchar2(100) PATH 'apellidos',
                  FEC_NACIMIENTO varchar2(100) PATH 'fechaNacimiento',
                  SEXO varchar2(100) PATH 'sexo') XT) loop*/
  
    FOR C IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'ruc/text()') RUC,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'identificador/text()') NRO_RUC,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'digitoVerificador/text()') DIGITO,
                     EXTRACTVALUE(VALUE(P), V_PATH_DET_PERSONA ||
                                   'nombre/text()') NOM_EMPRESA
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
    
      R_GE_EQF_CHK_DET_PERSONA.COD_PERSONA        := PI_COD_PERSONA;
      R_GE_EQF_CHK_DET_PERSONA.FEC_CONSULTA       := G_FEC_ACTUAL;
      R_GE_EQF_CHK_DET_PERSONA.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
      R_GE_EQF_CHK_DET_PERSONA.USU_INSERCION      := USER;
      R_GE_EQF_CHK_DET_PERSONA.FEC_INSERCION      := SYSDATE;
      R_GE_EQF_CHK_DET_PERSONA.USU_MODIFICACION   := USER;
      R_GE_EQF_CHK_DET_PERSONA.FEC_MODIFICACION   := SYSDATE;
      R_GE_EQF_CHK_DET_PERSONA.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
      R_GE_EQF_CHK_DET_PERSONA.NRO_SOLICITUD      := G_NRO_SOLICITUD;
      R_GE_EQF_CHK_DET_PERSONA.NRO_SECUENCIA      := G_NRO_SECUENCIA;
    
      R_GE_EQF_CHK_DET_PERSONA.TIP_DOCUMENTO := G_TIP_DOCUMENTO;
      R_GE_EQF_CHK_DET_PERSONA.NRO_DOCUMENTO := C.NRO_RUC || '-' ||
                                                C.DIGITO;
      R_GE_EQF_CHK_DET_PERSONA.NOMBRE        := C.NOM_EMPRESA;
      --registro de datos
      BEGIN
        INSERT INTO GE_EQF_CHK_DET_PERSONAS
        VALUES R_GE_EQF_CHK_DET_PERSONA;
      EXCEPTION
        WHEN OTHERS THEN
          G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                         G_PROCESO || ': ' || SQLERRM;
          RAISE G_ERROR;
      END;
    
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_CONSULTBANC(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                       P_XMLRESPUESTA IN XMLTYPE,
                                       P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_CON_BANCARIAS VARCHAR2(500);
  BEGIN
    G_PROCESO              := 'Consultas Bancarias';
    V_PATH_CON_BANCARIAS   := 'consulta/';
    G_NRO_SECUENCIA        := 0;
    R_GE_EQF_CHK_CONSULTAS := NULL;
  
    FOR R5 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_CON_BANCARIAS ||
                                    'entidad/text()') NOM_ENTIDAD,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_BANCARIAS ||
                                    'codigoEntidad/text()') COD_ENTIDAD,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_BANCARIAS ||
                                    'fecha/text()') FECHA,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_BANCARIAS ||
                                    'motivo/text()') MOTIVO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_BANCARIAS ||
                                    'operacion/text()') OPERACION
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/consultasHistoricasBancariaFinanciera/consulta'))) P)
    LOOP
      /*for R5 in (select XT.*
      from XMLTABLE(V_PATH_CON_BANCARIAS PASSING P_XMLRESPUESTA COLUMNS
      NOM_ENTIDAD varchar2(100) PATH 'entidad',
       COD_ENTIDAD varchar2(100) PATH 'codigoEntidad',
       FECHA varchar2(100) PATH 'fecha',
       MOTIVO varchar2(100) PATH 'motivo',
       OPERACION varchar2(100) PATH 'operacion') XT) loop*/
      IF R5.COD_ENTIDAD IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_CONSULTAS.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_CONSULTAS.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_CONSULTAS.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_CONSULTAS.USU_INSERCION      := USER;
        R_GE_EQF_CHK_CONSULTAS.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_CONSULTAS.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_CONSULTAS.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_CONSULTAS.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_CONSULTAS.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_CONSULTAS.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_CONSULTAS.TIP_CONSULTA       := 'BANCARIA';
      
        R_GE_EQF_CHK_CONSULTAS.NOM_ENTIDAD := R5.NOM_ENTIDAD;
        R_GE_EQF_CHK_CONSULTAS.COD_ENTIDAD := R5.COD_ENTIDAD;
        R_GE_EQF_CHK_CONSULTAS.FECHA       := R5.FECHA;
        R_GE_EQF_CHK_CONSULTAS.MOTIVO      := R5.MOTIVO;
        R_GE_EQF_CHK_CONSULTAS.OPERACION   := R5.OPERACION;
      
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_CONSULTAS
          VALUES R_GE_EQF_CHK_CONSULTAS;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_CONSULTPUBL(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                       P_XMLRESPUESTA IN XMLTYPE,
                                       P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_CON_PUBLICAS VARCHAR2(500);
  BEGIN
    G_PROCESO              := 'Consulta pública';
    V_PATH_CON_PUBLICAS    := 'consulta/';
    G_NRO_SECUENCIA        := 0;
    R_GE_EQF_CHK_CONSULTAS := NULL;
    FOR R6 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_CON_PUBLICAS ||
                                    'entidad/text()') NOM_ENTIDAD,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_PUBLICAS ||
                                    'codigoEntidad/text()') COD_ENTIDAD,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_PUBLICAS ||
                                    'fecha/text()') FECHA,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_PUBLICAS ||
                                    'motivo/text()') MOTIVO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CON_PUBLICAS ||
                                    'operacion/text()') OPERACION
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/consultasHistoricasPublicas/consulta'))) P)
    LOOP
      /*for R6 in (select XT.*
      from XMLTABLE(V_PATH_CON_PUBLICAS PASSING P_XMLRESPUESTA COLUMNS NOM_ENTIDAD varchar2(100) PATH 'entidad', COD_ENTIDAD varchar2(100) PATH 'codigoEntidad', FECHA varchar2(100) PATH 'fecha', MOTIVO varchar2(100) PATH 'motivo', OPERACION varchar2(100) PATH 'operacion') XT) loop*/
      IF R6.COD_ENTIDAD IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_CONSULTAS.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_CONSULTAS.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_CONSULTAS.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_CONSULTAS.USU_INSERCION      := USER;
        R_GE_EQF_CHK_CONSULTAS.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_CONSULTAS.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_CONSULTAS.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_CONSULTAS.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_CONSULTAS.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_CONSULTAS.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_CONSULTAS.TIP_CONSULTA       := 'PUBLICA';
      
        R_GE_EQF_CHK_CONSULTAS.NOM_ENTIDAD := R6.NOM_ENTIDAD;
        R_GE_EQF_CHK_CONSULTAS.COD_ENTIDAD := R6.COD_ENTIDAD;
        R_GE_EQF_CHK_CONSULTAS.FECHA       := R6.FECHA;
        R_GE_EQF_CHK_CONSULTAS.MOTIVO      := R6.MOTIVO;
        R_GE_EQF_CHK_CONSULTAS.OPERACION   := R6.OPERACION;
      
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_CONSULTAS
          VALUES R_GE_EQF_CHK_CONSULTAS;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_CHEQ_REC(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                    P_XMLRESPUESTA IN XMLTYPE,
                                    P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_CHEQ_REC VARCHAR2(500);
  BEGIN
    G_PROCESO            := 'Cheque Rechazado';
    V_PATH_CHEQ_REC      := 'cheque/';
    G_NRO_SECUENCIA      := 0;
    R_GE_EQF_CHK_CHE_REC := NULL;
    FOR R IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC || 'banco/text()') NOM_BANCO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'codigoBanco/text()') COD_BANCO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'ctaCte/text()') CTA_CTE,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'chequeNumero/text()') NRO_CHEQUE,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'fechaRechazo/text()') FEC_RECHAZO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC || 'monto/text()') MONTO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'moneda/text()') MONEDA,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'motivoRechazo/text()') MOT_RECHAZO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'motivoRechazoId/text()') COD_MOT_RECHAZO,
                     EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC ||
                                   'estado/text()') ESTADO
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/chequesRechazados/cheque'))) P)
    LOOP
      /*for R in (select XT.*
      from XMLTABLE(V_PATH_CHEQ_REC PASSING P_XMLRESPUESTA COLUMNS
                    --cheque rechazado histórico--
                    NOM_BANCO varchar2(100) PATH 'banco',
                    COD_BANCO varchar2(100) PATH 'codigoBanco',
                    CTA_CTE varchar2(100) PATH 'ctaCte',
                    NRO_CHEQUE varchar2(100) PATH 'chequeNumero',
                    FEC_RECHAZO varchar2(100) PATH 'fechaRechazo',
                    MONTO varchar2(100) PATH 'monto',
                    MONEDA varchar2(100) PATH 'moneda',
                    MOT_RECHAZO varchar2(100) PATH 'motivoRechazo',
                    COD_MOT_RECHAZO varchar2(100) PATH 'motivoRechazoId',
                    ESTADO varchar2(100) PATH 'estado') XT) loop*/
      IF R.COD_BANCO IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_CHE_REC.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_CHE_REC.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_CHE_REC.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_CHE_REC.USU_INSERCION      := USER;
        R_GE_EQF_CHK_CHE_REC.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_CHE_REC.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_CHE_REC.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_CHE_REC.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_CHE_REC.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_CHE_REC.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_CHE_REC.IND_HISTORICO      := 'N'; --no es histórico
        R_GE_EQF_CHK_CHE_REC.TIP_CHEQUE         := 'RECHAZADO';
      
        R_GE_EQF_CHK_CHE_REC.NOM_BANCO       := R.NOM_BANCO;
        R_GE_EQF_CHK_CHE_REC.COD_BANCO       := R.COD_BANCO;
        R_GE_EQF_CHK_CHE_REC.NRO_CHEQUE      := R.NRO_CHEQUE;
        R_GE_EQF_CHK_CHE_REC.NRO_CTA_CTE     := R.CTA_CTE;
        R_GE_EQF_CHK_CHE_REC.FEC_RECHAZO     := R.FEC_RECHAZO;
        R_GE_EQF_CHK_CHE_REC.MONTO           := R.MONTO;
        R_GE_EQF_CHK_CHE_REC.MONEDA          := R.MONEDA;
        R_GE_EQF_CHK_CHE_REC.MOT_RECHAZO     := R.MOT_RECHAZO;
        R_GE_EQF_CHK_CHE_REC.COD_MOT_RECHAZO := R.COD_MOT_RECHAZO;
        R_GE_EQF_CHK_CHE_REC.ESTADO          := R.ESTADO;
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_CHEQUES
          VALUES R_GE_EQF_CHK_CHE_REC;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
  
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_CHEQ_ANU(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                    P_XMLRESPUESTA IN XMLTYPE,
                                    P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_CHEQ_ANULADO VARCHAR2(500);
  BEGIN
    G_PROCESO            := 'Cheques Anulados';
    V_PATH_CHEQ_ANULADO  := 'cheque/';
    G_NRO_SECUENCIA      := 0;
    R_GE_EQF_CHK_CHE_ANU := NULL;
    FOR R1 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'banco/text()') NOM_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'codigoBanco/text()') COD_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'ctaCte/text()') CTA_CTE,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'chequeNumero/text()') NRO_CHEQUE,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'fechaRechazo/text()') FEC_RECHAZO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'monto/text()') MONTO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'moneda/text()') MONEDA,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'motivoAnulacion/text()') MOT_ANULACION,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_ANULADO ||
                                    'motivoAnulacionId/text()') COD_MOT_ANULACION
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/chequesAnulados/cheque'))) P)
    LOOP
      /*for R1 in (select XT.*
      from XMLTABLE(V_PATH_CHEQ_ANULADO PASSING P_XMLRESPUESTA COLUMNS NOM_BANCO varchar2(100) PATH 'banco',
                    COD_BANCO varchar2(100) PATH 'codigoBanco',
                    CTA_CTE varchar2(100) PATH 'ctaCte',
                    NRO_CHEQUE varchar2(100) PATH 'chequeNumero',
                    MONTO varchar2(100) PATH 'monto',
                    MONEDA varchar2(100) PATH 'moneda',
                    MOT_ANULACION varchar2(100) PATH 'motivoAnulacion',
                    COD_MOT_ANULACION varchar2(100) PATH 'motivoAnulacionId') XT) loop*/
      IF R1.COD_BANCO IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_CHE_ANU.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_CHE_ANU.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_CHE_ANU.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_CHE_ANU.USU_INSERCION      := USER;
        R_GE_EQF_CHK_CHE_ANU.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_CHE_ANU.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_CHE_ANU.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_CHE_ANU.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_CHE_ANU.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_CHE_ANU.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_CHE_ANU.IND_HISTORICO      := 'N'; -- histórico
        R_GE_EQF_CHK_CHE_ANU.TIP_CHEQUE         := 'ANULADO';
      
        R_GE_EQF_CHK_CHE_ANU.NOM_BANCO         := R1.NOM_BANCO;
        R_GE_EQF_CHK_CHE_ANU.COD_BANCO         := R1.COD_BANCO;
        R_GE_EQF_CHK_CHE_ANU.NRO_CHEQUE        := R1.NRO_CHEQUE;
        R_GE_EQF_CHK_CHE_ANU.MONTO             := R1.MONTO;
        R_GE_EQF_CHK_CHE_ANU.MONEDA            := R1.MONEDA;
        R_GE_EQF_CHK_CHE_ANU.MOT_ANULACION     := R1.MOT_ANULACION;
        R_GE_EQF_CHK_CHE_ANU.COD_MOT_ANULACION := R1.COD_MOT_ANULACION;
      
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_CHEQUES
          VALUES R_GE_EQF_CHK_CHE_ANU;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_CHEQ_RECHIST(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                        P_XMLRESPUESTA IN XMLTYPE,
                                        P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_CHEQ_REC_HIST VARCHAR2(500);
  BEGIN
    G_PROCESO                := 'Cheque rechazados históricos';
    V_PATH_CHEQ_REC_HIST     := 'cheque/';
    G_NRO_SECUENCIA          := 0;
    R_GE_EQF_CHK_CHE_RECHIST := NULL;
    FOR C1 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'banco/text()') NOM_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'codigoBanco/text()') COD_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'ctaCte/text()') CTA_CTE,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'chequeNumero/text()') NRO_CHEQUE,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'fechaRechazo/text()') FEC_RECHAZO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'monto/text()') MONTO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'moneda/text()') MONEDA,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'motivoRechazo/text()') MOT_RECHAZO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'motivoRechazoId/text()') COD_MOT_RECHAZO,
                      EXTRACTVALUE(VALUE(P), V_PATH_CHEQ_REC_HIST ||
                                    'estado/text()') ESTADO
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/chequesRechazadosHistorico/cheque'))) P)
    LOOP
      /*for C1 in (select XT.*
      from XMLTABLE(V_PATH_CHEQ_REC_HIST PASSING P_XMLRESPUESTA COLUMNS
                    --cheque rechazado histórico--
                    NOM_BANCO varchar2(100) PATH 'banco',
                    COD_BANCO varchar2(100) PATH 'codigoBanco',
                    CTA_CTE varchar2(100) PATH 'ctaCte',
                    NRO_CHEQUE varchar2(100) PATH 'chequeNumero',
                    FEC_RECHAZO varchar2(100) PATH 'fechaRechazo',
                    MONTO varchar2(100) PATH 'monto',
                    MONEDA varchar2(100) PATH 'moneda',
                    MOT_RECHAZO varchar2(100) PATH 'motivoRechazo',
                    COD_MOT_RECHAZO varchar2(100) PATH 'motivoRechazoId',
                    ESTADO varchar2(100) PATH 'estado') XT) loop*/
      IF C1.COD_BANCO IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_CHE_RECHIST.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_CHE_RECHIST.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_CHE_RECHIST.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_CHE_RECHIST.USU_INSERCION      := USER;
        R_GE_EQF_CHK_CHE_RECHIST.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_CHE_RECHIST.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_CHE_RECHIST.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_CHE_RECHIST.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_CHE_RECHIST.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_CHE_RECHIST.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_CHE_RECHIST.IND_HISTORICO      := 'S'; --no es histórico
        R_GE_EQF_CHK_CHE_RECHIST.TIP_CHEQUE         := 'RECHAZADO_HISTORICO';
      
        R_GE_EQF_CHK_CHE_RECHIST.NOM_BANCO       := C1.NOM_BANCO;
        R_GE_EQF_CHK_CHE_RECHIST.COD_BANCO       := C1.COD_BANCO;
        R_GE_EQF_CHK_CHE_RECHIST.NRO_CHEQUE      := C1.NRO_CHEQUE;
        R_GE_EQF_CHK_CHE_RECHIST.NRO_CTA_CTE     := C1.CTA_CTE;
        R_GE_EQF_CHK_CHE_RECHIST.FEC_RECHAZO     := C1.FEC_RECHAZO;
        R_GE_EQF_CHK_CHE_RECHIST.MONTO           := C1.MONTO;
        R_GE_EQF_CHK_CHE_RECHIST.MONEDA          := C1.MONEDA;
        R_GE_EQF_CHK_CHE_RECHIST.MOT_RECHAZO     := C1.MOT_RECHAZO;
        R_GE_EQF_CHK_CHE_RECHIST.COD_MOT_RECHAZO := C1.COD_MOT_RECHAZO;
        R_GE_EQF_CHK_CHE_RECHIST.ESTADO          := C1.ESTADO;
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_CHEQUES
          VALUES R_GE_EQF_CHK_CHE_RECHIST;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_SITUACION(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                     P_XMLRESPUESTA IN XMLTYPE,
                                     P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_SIT_BANCARIA VARCHAR2(500);
  BEGIN
    G_PROCESO           := 'Situación Bancaria';
    V_PATH_SIT_BANCARIA := 'ServResponse/data/persona/situacionBancaria/';
    G_NRO_SECUENCIA     := 0;
    FOR C IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_SIT_BANCARIA ||
                                   'estadoId/text()') COD_ESTADO,
                     EXTRACTVALUE(VALUE(P), V_PATH_SIT_BANCARIA ||
                                   'estado/text()') NOM_ESTADO
              
              FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse'))) P)
    LOOP
      --actualizamos la PERSONA
      IF C.COD_ESTADO IS NOT NULL THEN
        BEGIN
          UPDATE GE_EQF_CHK_DET_PERSONAS T
          SET T.SIT_BAN_ESTADO     = C.NOM_ESTADO,
              T.SIT_BAN_EST_CODIGO = C.COD_ESTADO
          WHERE T.NRO_SOLICITUD = G_NRO_SOLICITUD
          AND T.COD_PERSONA = PI_COD_PERSONA;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;

  PROCEDURE PR_PRO_XML_CHK_INHABIL(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                   P_XMLRESPUESTA IN XMLTYPE,
                                   P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_INHABILIT VARCHAR2(500);
  BEGIN
    G_PROCESO              := 'Inhabilitaciones';
    V_PATH_INHABILIT       := 'inhabilitacion/';
    G_NRO_SECUENCIA        := 0;
    R_GE_EQF_CHK_INHABILIT := NULL;
    FOR R3 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'banco/text()') NOM_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'codigoBanco/text()') COD_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'falta/text()') FALTA,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'tiempo/text()') TIEMPO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'fechaInhabilitacion/text()') FEC_INHABILIT,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'numeroInhabilitacionCircular/text()') NRO_CIRCULAR,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT ||
                                    'fechaInhabilitacionCircular/text()') FEC_CIRCULAR
               
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/inhabilitaciones/inhabilitacion'))) P)
    LOOP
    
      /*for R3 in (select XT.*
      from XMLTABLE(V_PATH_INHABILIT PASSING P_XMLRESPUESTA COLUMNS
      NOM_BANCO varchar2(100) PATH 'banco',
                    COD_BANCO varchar2(100) PATH 'codigoBanco',
                    FALTA varchar2(100) PATH 'falta',
                    TIEMPO varchar2(100) PATH 'tiempo',
                    FEC_INHABILIT varchar2(100) PATH 'fechaInhabilitacion',
                    NRO_CIRCULAR varchar2(100) PATH 'numeroInhabilitacionCircular',
                    FEC_CIRCULAR varchar2(100) PATH 'fechaInhabilitacionCircular') XT) loop*/
      IF R3.COD_BANCO IS NOT NULL THEN
      
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_INHABILIT.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_INHABILIT.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_INHABILIT.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_INHABILIT.USU_INSERCION      := USER;
        R_GE_EQF_CHK_INHABILIT.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_INHABILIT.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_INHABILIT.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_INHABILIT.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_INHABILIT.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_INHABILIT.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_INHABILIT.IND_HISTORICO      := 'N'; -- histórico
      
        R_GE_EQF_CHK_INHABILIT.NOM_BANCO          := R3.NOM_BANCO;
        R_GE_EQF_CHK_INHABILIT.COD_BANCO          := R3.COD_BANCO;
        R_GE_EQF_CHK_INHABILIT.FALTA              := R3.FALTA;
        R_GE_EQF_CHK_INHABILIT.TIEMPO             := R3.TIEMPO;
        R_GE_EQF_CHK_INHABILIT.FEC_INHABILITACION := R3.FEC_INHABILIT;
        R_GE_EQF_CHK_INHABILIT.NRO_INH_CIRCULAR   := R3.NRO_CIRCULAR;
        R_GE_EQF_CHK_INHABILIT.FEC_INH_CIRCULAR   := R3.FEC_CIRCULAR;
      
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_INHABILITACIONES
          VALUES R_GE_EQF_CHK_INHABILIT;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;
  PROCEDURE PR_PRO_XML_CHK_INHABILHIST(PI_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                       P_XMLRESPUESTA IN XMLTYPE,
                                       P_MENSAJE      OUT VARCHAR2) IS
    V_PATH_INHABILIT_HIST VARCHAR2(500);
  BEGIN
    G_PROCESO             := 'Inhabilitaciones históricas';
    V_PATH_INHABILIT_HIST := 'inhabilitacion/';
  
    G_NRO_SECUENCIA        := 0;
    R_GE_EQF_CHK_INHABILIT := NULL;
    FOR R4 IN (SELECT EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'banco/text()') NOM_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'codigoBanco/text()') COD_BANCO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'falta/text()') FALTA,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'tiempo/text()') TIEMPO,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'fechaInhabilitacion/text()') FEC_INHABILIT,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'numeroInhabilitacionCircular/text()') NRO_CIRCULAR,
                      EXTRACTVALUE(VALUE(P), V_PATH_INHABILIT_HIST ||
                                    'fechaInhabilitacionCircular/text()') FEC_CIRCULAR
               
               FROM TABLE(XMLSEQUENCE(EXTRACT(P_XMLRESPUESTA, '/ServResponse/data/persona/inhabilitacionesHistoricas/inhabilitacion'))) P)
    LOOP
    
      /*for R4 in (select XT.*
      from XMLTABLE(V_PATH_INHABILIT_HIST PASSING P_XMLRESPUESTA COLUMNS NOM_BANCO varchar2(100) PATH 'banco',
                    COD_BANCO varchar2(100) PATH 'codigoBanco',
                    FALTA varchar2(100) PATH 'falta',
                    TIEMPO varchar2(100) PATH 'tiempo',
                    FEC_INHABILIT varchar2(100) PATH 'fechaInhabilitacion',
                    NRO_CIRCULAR varchar2(100) PATH 'numeroInhabilitacionCircular',
                    FEC_CIRCULAR varchar2(100) PATH 'fechaInhabilitacionCircular') XT) loop*/
    
      IF R4.COD_BANCO IS NOT NULL THEN
        G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
      
        R_GE_EQF_CHK_INHABILIT.COD_PERSONA        := PI_COD_PERSONA;
        R_GE_EQF_CHK_INHABILIT.FEC_CONSULTA       := G_FEC_ACTUAL;
        R_GE_EQF_CHK_INHABILIT.HOR_CONSULTA       := TO_CHAR(SYSDATE, 'hh24:mi:ss');
        R_GE_EQF_CHK_INHABILIT.USU_INSERCION      := USER;
        R_GE_EQF_CHK_INHABILIT.FEC_INSERCION      := SYSDATE;
        R_GE_EQF_CHK_INHABILIT.USU_MODIFICACION   := USER;
        R_GE_EQF_CHK_INHABILIT.FEC_MODIFICACION   := SYSDATE;
        R_GE_EQF_CHK_INHABILIT.NOM_SER_WEBSERVICE := G_NOM_SERVICIO;
        R_GE_EQF_CHK_INHABILIT.NRO_SOLICITUD      := G_NRO_SOLICITUD;
        R_GE_EQF_CHK_INHABILIT.NRO_SECUENCIA      := G_NRO_SECUENCIA;
        R_GE_EQF_CHK_INHABILIT.IND_HISTORICO      := 'S'; -- histórico
      
        R_GE_EQF_CHK_INHABILIT.NOM_BANCO          := R4.NOM_BANCO;
        R_GE_EQF_CHK_INHABILIT.COD_BANCO          := R4.COD_BANCO;
        R_GE_EQF_CHK_INHABILIT.FALTA              := R4.FALTA;
        R_GE_EQF_CHK_INHABILIT.TIEMPO             := R4.TIEMPO;
        R_GE_EQF_CHK_INHABILIT.FEC_INHABILITACION := R4.FEC_INHABILIT;
        R_GE_EQF_CHK_INHABILIT.NRO_INH_CIRCULAR   := R4.NRO_CIRCULAR;
        R_GE_EQF_CHK_INHABILIT.FEC_INH_CIRCULAR   := R4.FEC_CIRCULAR;
      
        --registro de datos
        BEGIN
          INSERT INTO GE_EQF_CHK_INHABILITACIONES
          VALUES R_GE_EQF_CHK_INHABILIT;
        EXCEPTION
          WHEN OTHERS THEN
            G_MSG_ERROR := G_MSG_ERROR || ' -Error al insertar datos de ' ||
                           G_PROCESO || ': ' || SQLERRM;
            RAISE G_ERROR;
        END;
      END IF;
    END LOOP;
    P_MENSAJE := '';
  EXCEPTION
    WHEN OTHERS THEN
      G_MSG_ERROR := G_MSG_ERROR || ' -Error al procesar  ' || G_PROCESO || ': ' ||
                     SQLERRM;
      RAISE G_ERROR;
  END;

  FUNCTION FU_PRO_DAT_INFORMCONF(P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_IND_REINTENTO IN VARCHAR2,
                                 P_TIP_SERVICIO  IN NUMBER) RETURN VARCHAR2 IS
    V_PAR_INGRESO VARCHAR2(500);
    V_RESPUESTA   CLOB;
    V_OK          VARCHAR2(1); -- indica si el socket se corto o no
  
    --V_NRO_DOCUMENTO BA_PERSONAS.NRO_DOCUMENTO%type;
    --V_TIP_SERVICIO  varchar2(2);
    XMLRESPUESTA XMLTYPE;
  
  BEGIN
    G_IND_REINTENTO := P_IND_REINTENTO;
    G_FEC_ACTUAL    := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
    G_TIP_PERSONA   := FU_OBT_TIP_PERSONA(P_COD_PERSONA);
    G_NRO_DOCUMENTO := FUE_OBT_NRO_DOC_PERSONA(P_COD_PERSONA);
    G_TIP_DOCUMENTO := FU_OBT_TIP_DOCUMENTO(P_COD_PERSONA);
  
    IF G_TIP_DOCUMENTO = 'CI' THEN
      /*error al convertir cedula con letra se reemplaza por funcion DYDMR-23345*/
      G_NRO_DOCUMENTO := FU_OBT_NRO_DOCUMENTO(G_NRO_DOCUMENTO); --TRIM(REPLACE(TO_CHAR(G_NRO_DOCUMENTO, '999G999G999G999'), ',', '.'));
    END IF;
  
    G_ACU_ERRORES  := 0;
    G_MSG_PROCESO  := NULL; --
    G_TIP_SERVICIO := P_TIP_SERVICIO;
    --se obtiene el parámetro de envío y el nombre del servicio
    PR_OBT_PAR_SER_INFORMCONF(P_TIP_SERVICIO, G_PAR_ENVIO, G_NOM_SERVICIO);
    --mensaje para el socket de tipo servicio nuevo
    V_PAR_INGRESO := G_TIP_PERSONA || G_PAR_ENVIO || G_NRO_DOCUMENTO;
    --llamada al socket
  
    --V_OK := FUE_ENV_TCP_MSJLONG(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
    V_OK             := FU_ENV_TCP_MSJCLOB(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
    G_PRO_INDIVIDUAL := 'S';
    --asignación tipo de persona
    IF G_TIP_PERSONA = 'PE' THEN
      G_TIP_PERSONA := 'F';
    ELSE
      G_TIP_PERSONA := 'J';
    END IF;
    --Control de errores
    IF V_OK != 'S' THEN
    
      G_MSG_ERROR := G_MSG_ERROR || ' -Error con el Socket Informconf.c' ||
                     V_RESPUESTA;
      RAISE G_ERROR;
    ELSE
      XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
      FOR R IN (SELECT EXTRACTVALUE(VALUE(P), 'ServResponse/Status/text()') AS STATUS,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/code/text()') AS COD_ERROR,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/externalCode/text()') AS COD_EXT_ERROR,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/message/text()') AS MENSAJE_ERROR
                FROM TABLE(XMLSEQUENCE(EXTRACT(XMLRESPUESTA, '/ServResponse'))) P)
      LOOP
        IF R.STATUS != 'OK' THEN
        
          IF R.STATUS != 'OK' THEN
            G_MSG_ERROR := G_MSG_ERROR || 'Error: cod error:' ||
                           R.COD_ERROR || ' cod externo:' ||
                           R.COD_EXT_ERROR || ' mensaje:' ||
                           R.MENSAJE_ERROR;
            RAISE G_ERROR;
          END IF;
        
        END IF;
      END LOOP;
    END IF;
  
    --se recibe la respuesta del socket
    XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
  
    /*si es reintento, se busca la nro de solicitud anterior que corresponda a la persona
    * si no es reintento, se obtiene el sgte nro de solicitud
    */
    IF P_IND_REINTENTO = 'S' THEN
      G_NRO_SOLICITUD := FU_OBT_NRO_SOLICITUD(P_COD_PERSONA);
    ELSE
      --nueva solicitud
      G_NRO_SOLICITUD := S_EQF_NRO_SOLICITUD.NEXTVAL();
      PR_INS_SOLICITUD_INF(G_NRO_SOLICITUD, P_COD_PERSONA);
    END IF;
  
    --procesamiento del XML de acuerdo al servicio solicitado
    IF P_TIP_SERVICIO = 1 THEN
      --socoring
      PR_PRO_XML_SCORING(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 2 THEN
      --convocatoria resumen
      PR_PRO_XML_CONVOCATORIA_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 3 THEN
      --demanda resumen
      PR_PRO_XML_DEMANDA_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 4 THEN
      --Inhabilitación resumen (Cuentas)
      PR_PRO_XML_INHABILITACIO_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 5 THEN
      --Inhabilitación resumen (Cuentas)
      PR_PRO_XML_INHIBICIONES_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 6 THEN
      --Morosidad actidades Adefi
      PR_PRO_XML_MOR_ACT_ADEFI(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 7 THEN
      --Morosidad actividad
      PR_PRO_XML_MOR_ACTIVIDAD(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 8 THEN
      --Remates resumen
      PR_PRO_XML_REMATES_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 9 THEN
      --Solicitud de detalle (física y jurídica)
      PR_PRO_XML_SOL_DETALLE(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    ELSIF P_TIP_SERVICIO = 10 THEN
      --Quiebras resumen
      PR_PRO_XML_QUIEBRAS_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
    
    ELSIF P_TIP_SERVICIO = 11 THEN
      --Reporte PDF de la persona
      PR_PRO_XML_REPORTE_PDF(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
    
    ELSIF P_TIP_SERVICIO = 99 THEN
      --todos los servicios
      G_PRO_INDIVIDUAL := 'N';
      PR_PRO_XML_SCORING(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_CONVOCATORIA_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_DEMANDA_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_INHABILITACIO_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_INHIBICIONES_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_MOR_ACT_ADEFI(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_MOR_ACTIVIDAD(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_REMATES_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_SOL_DETALLE(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_QUIEBRAS_RES(P_COD_PERSONA, XMLRESPUESTA, G_PRO_INDIVIDUAL, G_MSG_PROCESO);
      PR_PRO_XML_REPORTE_PDF(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
    
    END IF;
  
    COMMIT;
    --control de mensaje de finalización de proceso
    IF P_TIP_SERVICIO = 99 THEN
      IF G_ACU_ERRORES > 0 THEN
        RETURN 'Proceso terminado: reintentar servicios con errores';
      ELSE
        RETURN 'Proceso terminado correctamente';
      END IF;
    ELSE
      RETURN G_MSG_PROCESO;
    END IF;
  
  EXCEPTION
    WHEN G_ERROR THEN
      LP_REG_OPERACION(V_PAR_INGRESO, 'EQF_INFINT: ' || SQLERRM ||
                        G_MSG_ERROR);
      ROLLBACK;
      RETURN G_MSG_ERROR;
    
    WHEN OTHERS THEN
      LP_REG_OPERACION(V_PAR_INGRESO, 'EQF_INF: ' || SQLERRM || '-' ||
                        G_MSG_ERROR);
      ROLLBACK;
      RETURN 'Error al procesar los datos de Informconf: ' || SQLERRM;
  END;

  FUNCTION FU_PRO_DAT_INFOCHECK(P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_IND_REINTENTO IN VARCHAR2,
                                P_TIP_SERVICIO  IN NUMBER) RETURN VARCHAR2 IS
    V_PAR_INGRESO VARCHAR2(500);
    V_RESPUESTA   CLOB;
    V_OK          VARCHAR2(1); -- indica si el socket se corto o no
  
    --V_NRO_DOCUMENTO BA_PERSONAS.NRO_DOCUMENTO%type;
    --V_TIP_SERVICIO  varchar2(2);
    XMLRESPUESTA XMLTYPE;
  
  BEGIN
    --G_IND_REINTENTO := P_IND_REINTENTO;
    G_FEC_ACTUAL    := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
    G_TIP_DOCUMENTO := FU_OBT_TIP_DOCUMENTO(P_COD_PERSONA);
    G_NRO_DOCUMENTO := FUE_OBT_NRO_DOC_PERSONA(P_COD_PERSONA);
    G_MSG_PROCESO   := NULL; --
    --el documento RUC se envía sin los separadores de miles
    IF G_TIP_DOCUMENTO = 'CI' THEN
      /*error al convertir cedula con letra se reemplaza por funcion DYDMR-23345*/
      G_NRO_DOCUMENTO := FU_OBT_NRO_DOCUMENTO(G_NRO_DOCUMENTO); --TRIM(REPLACE(TO_CHAR(G_NRO_DOCUMENTO, '999G999G999G999'), ',', '.'));
    END IF;
    --G_TIP_PERSONA := FU_OBT_TIP_PERSONA(P_COD_PERSONA);
  
    G_TIP_SERVICIO := P_TIP_SERVICIO;
    --se obtiene el parámetro de envío y el nombre del servicio
    PR_OBT_PAR_SER_INFOCHECK(P_TIP_SERVICIO, G_PAR_ENVIO, G_NOM_SERVICIO);
  
    --mensaje para el socket de tipo servicio nuevo
    --V_PAR_INGRESO := 'CH#INFO_V2#RUC|80008892-1|5|3';
    V_PAR_INGRESO := G_PAR_ENVIO || G_TIP_DOCUMENTO || '|' ||
                     G_NRO_DOCUMENTO || G_TIP_MOT_OPE;
  
    --llamada al socket
    V_OK := FU_ENV_TCP_MSJCLOB(G_SCK_SERVIDOR, G_SCK_PUERTO, G_TIE_ESPERA, V_PAR_INGRESO, V_RESPUESTA);
  
    --Control de errores
    IF V_OK != 'S' THEN
    
      G_MSG_ERROR := G_MSG_ERROR || ' -Error con el Socket Informconf.c' ||
                     V_RESPUESTA;
      RAISE G_ERROR;
    ELSE
      XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
      FOR R IN (SELECT EXTRACTVALUE(VALUE(P), 'ServResponse/Status/text()') AS STATUS,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/code/text()') AS COD_ERROR,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/externalCode/text()') AS COD_EXT_ERROR,
                       EXTRACTVALUE(VALUE(P), 'ServResponse/error/message/text()') AS MENSAJE_ERROR
                FROM TABLE(XMLSEQUENCE(EXTRACT(XMLRESPUESTA, '/ServResponse'))) P)
      LOOP
        IF R.STATUS != 'OK' THEN
          --G_MSG_ERROR := G_MSG_ERROR || 'Error: cod error:' || R.COD_ERROR || ' cod externo:' || R.COD_EXT_ERROR || ' mensaje:' || R.MENSAJE_ERROR;
          --Cod error 80  documento no encontrado por parte de infocheck, se debe de asignar situación = 1 a la persona
          IF R.COD_EXT_ERROR = '80' THEN
            PR_ACT_DAT_INFOCHECK(P_COD_PERSONA);
            G_MSG_PROCESO := 'Infocheck Actualizado';
            COMMIT;
            RETURN G_MSG_PROCESO;
          ELSE
            G_MSG_ERROR := G_MSG_ERROR || 'Error: cod error:' ||
                           R.COD_ERROR || ' cod externo:' ||
                           R.COD_EXT_ERROR || ' mensaje:' ||
                           R.MENSAJE_ERROR;
            RAISE G_ERROR;
          END IF;
        
          RAISE G_ERROR;
        END IF;
      
      END LOOP;
    END IF;
  
    --se recibe la respuesta del socket
    XMLRESPUESTA := XMLTYPE(V_RESPUESTA);
  
    /*si es reintento, se busca la nro de solicitud anterior que corresponda a la persona
    * si no es reintento, se obtiene el sgte nro de solicitud
    */
    IF P_IND_REINTENTO = 'S' THEN
      G_NRO_SOLICITUD := FU_OBT_NRO_SOLICITUD(P_COD_PERSONA);
    ELSE
      --nueva solicitud
      G_NRO_SOLICITUD := S_EQF_NRO_SOLICITUD.NEXTVAL();
      PR_INS_SOLICITUD_INF(G_NRO_SOLICITUD, P_COD_PERSONA);
    END IF;
  
    --procesamiento del XML de acuerdo al servicio solicitado
    IF P_TIP_SERVICIO = 1 THEN
      IF G_TIP_DOCUMENTO != 'RUC' THEN
        PR_PRO_XML_CHK_DAT_PERSONA(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      ELSE
        PR_PRO_XML_CHK_DAT_EMPRESA(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      END IF;
      PR_PRO_XML_CHK_CHEQ_REC(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_CHEQ_RECHIST(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_CHEQ_ANU(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_INHABIL(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_INHABILHIST(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_CONSULTPUBL(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_CONSULTBANC(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_PRO_XML_CHK_SITUACION(P_COD_PERSONA, XMLRESPUESTA, G_MSG_PROCESO);
      PR_ACT_DAT_INFOCHECK(P_COD_PERSONA);
    
      G_MSG_PROCESO := ' Infocheck actualizado: Nro Solicitud ' ||
                       G_NRO_SOLICITUD;
    
    END IF;
  
    COMMIT;
    --control de mensaje de finalización de proceso
  
    RETURN G_MSG_PROCESO;
  
  EXCEPTION
    WHEN G_ERROR THEN
      LP_REG_OPERACION(V_PAR_INGRESO, 'EQF_CHKINT: ' || SQLERRM ||
                        G_MSG_ERROR);
      ROLLBACK;
      RETURN G_MSG_ERROR;
    
    WHEN OTHERS THEN
      LP_REG_OPERACION(V_PAR_INGRESO, 'EQF_CHK: ' || SQLERRM || '-' ||
                        G_MSG_ERROR);
      ROLLBACK;
      RETURN 'Error al procesar los datos de Infocheck: ' || SQLERRM;
  END;

END;
/

