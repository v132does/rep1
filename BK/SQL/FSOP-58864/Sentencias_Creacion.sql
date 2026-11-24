-- 1. DROP (con la nueva nomenclatura)

							  
--DROP TABLE IT.BA_LOG_OBJ_MODIFICADOS CASCADE CONSTRAINTS;


-- 2. CREATE TABLE (con la nueva nomenclatura)
CREATE TABLE IT.BA_LOG_OBJ_MODIFICADOS (
    NRO_JIRA           VARCHAR2(30) NOT NULL,
    NRO_ITEM           NUMBER(3)    NOT NULL,
    NOM_OBJETO         VARCHAR2(100) NOT NULL,
    USU_IMPLEMENTACION VARCHAR2(10) NOT NULL, 
    
    -- Campos separados de fecha y hora, según lo solicitado
    FEC_IMPLEMENTACION DATE         NOT NULL,
    HOR_IMPLEMENTACION VARCHAR2(8)  NOT NULL, 
    
    -- Columnas de Auditoría
    USU_INSERCION      VARCHAR2(10) DEFAULT SUBSTR(USER,1,10) NOT NULL, 
    FEC_INSERCION      DATE         DEFAULT SYSDATE NOT NULL, 
    USU_MODIFICACION   VARCHAR2(10) DEFAULT SUBSTR(USER,1,10) NOT NULL, 
    FEC_MODIFICACION   DATE         DEFAULT SYSDATE NOT NULL,


    -- Restricción (Primary Key) definida "in-line" y con nueva nomenclatura
    CONSTRAINT PK_BA_LOG_OBJ_MODIFICADOS PRIMARY KEY (NRO_JIRA, NRO_ITEM)
    
   
    
);

--GRANTEO DEL OBJETO GUIADO POR VORREGO. 
CREATE PUBLIC SYNONYM "BA_LOG_OBJ_MODIFICADOS" for IT.BA_LOG_OBJ_MODIFICADOS; 
GRANT ALL ON "IT"."BA_LOG_OBJ_MODIFICADOS" TO "IT_TEMPORAL";

-- 3. COMMENTS (con la nueva nomenclatura)
COMMENT ON TABLE IT.BA_LOG_OBJ_MODIFICADOS IS 'Bitácora que registra los objetos de base de datos implementados y su ticket de JIRA asociado.';


COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA IS 'Número del ticket de JIRA que ampara la implementación del objeto.';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM IS 'Número de ítem o secuencia';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO IS 'Nombre del objeto de base de datos implementado';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION IS 'Usuario que ejecutó el script de implementación en la base de datos.';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION IS 'Fecha en que se realizó la implementación del objeto.';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION IS 'Hora en que se realizó la implementación (Formato HH24:MI:SS).';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.USU_INSERCION IS 'Usuario de base de datos que insertó este registro en la bitácora (auditoría).';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.FEC_INSERCION IS 'Fecha en que se insertó este registro en la bitácora (auditoría).';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.USU_MODIFICACION IS 'Último usuario que modificó este registro (auditoría).';
COMMENT ON COLUMN IT.BA_LOG_OBJ_MODIFICADOS.FEC_MODIFICACION IS 'Última fecha de modificación de este registro (auditoría).';


/*************************************************************************************************************/


CREATE OR REPLACE PACKAGE IT.PAB_OBJ AS
    /**
     * Inserta un nuevo registro en la bitácora de objetos.
     */
    PROCEDURE P_INSERTAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         IN IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    );
    /**
     * Actualiza un registro existente, identificado por su llave primaria (JIRA + ITEM).
     */
    PROCEDURE P_ACTUALIZAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         IN IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    );
    /**
     * Elimina un registro de la bitácora, identificado por su llave primaria (JIRA + ITEM).
     */
    PROCEDURE P_ELIMINAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE
    );
    /**
     * Consulta (SELECT) que devuelve todos los objetos asociados a un número de JIRA.
     */
    PROCEDURE P_CONSULTAR_POR_JIRA (
        P_NRO_JIRA        IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_RESULTADOS_RC   OUT SYS_REFCURSOR
    );
    
    /**
     * Consulta (SELECT) que devuelve un único registro basado en su llave primaria (JIRA + ITEM).
     */
    PROCEDURE P_CONSULTAR_POR_PK (
        P_NRO_JIRA           IN  IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN  IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         OUT IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    );

    /**
     * (NUEVO) Consulta (SELECT) dinámica que devuelve registros basados en un criterio.
     * P_TIPO_CONSULTA: 'JIRA', 'OBJETO', 'USUARIO' o 'PK'.
     * P_VALOR_BUSQUEDA: El valor a buscar.
     * - Si TIPO = 'PK', P_VALOR_BUSQUEDA debe tener el formato "NRO_JIRA,NRO_ITEM".
     * P_RESULTADO_RC: Cursor de referencia (set de resultados).
     */
    PROCEDURE P_CONSULTAR_POR_PARAMETRO (
        P_TIPO_CONSULTA   IN VARCHAR2,
        P_VALOR_BUSQUEDA  IN VARCHAR2,
        P_RESULTADO_RC    OUT SYS_REFCURSOR
    );

END PAB_OBJ;
--/

/*************************************************************************************************************/


CREATE OR REPLACE PACKAGE BODY IT.PAB_OBJ AS
    PROCEDURE P_INSERTAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         IN IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    ) AS
    BEGIN
        INSERT INTO IT.BA_LOG_OBJ_MODIFICADOS (
            NRO_JIRA,
            NRO_ITEM,
            NOM_OBJETO,
            USU_IMPLEMENTACION,
            FEC_IMPLEMENTACION,
            HOR_IMPLEMENTACION
        ) VALUES (
            P_NRO_JIRA,
            P_NRO_ITEM,
            P_NOM_OBJETO,
            P_USU_IMPLEMENTACION,
            TRUNC(P_FEC_IMPLEMENTACION),
            P_HOR_IMPLEMENTACION
        );
        
        COMMIT; 
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; 
            RAISE_APPLICATION_ERROR(-20099,
                'Error general en PAB_OBJ.P_INSERTAR (Tabla: BA_LOG_OBJ_MODIFICADOS) para JIRA: ' || P_NRO_JIRA ||
                '. Error Oracle: ' || SQLERRM);
    END P_INSERTAR;
    
    --------------------------------------------------------------------------
    PROCEDURE P_ACTUALIZAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         IN IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION IN IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    ) AS
    BEGIN
        UPDATE IT.BA_LOG_OBJ_MODIFICADOS
        SET
            NOM_OBJETO = P_NOM_OBJETO,
            USU_IMPLEMENTACION = P_USU_IMPLEMENTACION,
            FEC_IMPLEMENTACION = TRUNC(P_FEC_IMPLEMENTACION),
            HOR_IMPLEMENTACION = P_HOR_IMPLEMENTACION,
            USU_MODIFICACION = SUBSTR(USER,1,10),
            FEC_MODIFICACION = SYSDATE
        WHERE
            NRO_JIRA = P_NRO_JIRA
            AND NRO_ITEM = P_NRO_ITEM;
            
        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'No se encontró el registro a actualizar (JIRA: ' || P_NRO_JIRA || ', ITEM: ' || P_NRO_ITEM || ').');
        END IF;
        
        COMMIT; 
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; 
            RAISE_APPLICATION_ERROR(-20099,
                'Error general en PAB_OBJ.P_ACTUALIZAR (Tabla: BA_LOG_OBJ_MODIFICADOS) para JIRA: ' || P_NRO_JIRA ||
                '. Error Oracle: ' || SQLERRM);
    END P_ACTUALIZAR;
    
    --------------------------------------------------------------------------
    PROCEDURE P_ELIMINAR (
        P_NRO_JIRA           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE
    ) AS
    BEGIN
        DELETE FROM IT.BA_LOG_OBJ_MODIFICados
        WHERE
            NRO_JIRA = P_NRO_JIRA
            AND NRO_ITEM = P_NRO_ITEM;
            
        IF SQL%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No se encontró el registro a eliminar (JIRA: ' || P_NRO_JIRA || ', ITEM: ' || P_NRO_ITEM || ').');
        END IF;
        
        COMMIT; 
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK; 
            RAISE_APPLICATION_ERROR(-20099,
                'Error general en PAB_OBJ.P_ELIMINAR (Tabla: BA_LOG_OBJ_MODIFICADOS) para JIRA: ' || P_NRO_JIRA ||
                '. Error Oracle: ' || SQLERRM);
    END P_ELIMINAR;
    
    --------------------------------------------------------------------------
    PROCEDURE P_CONSULTAR_POR_JIRA (
        P_NRO_JIRA        IN IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_RESULTADOS_RC   OUT SYS_REFCURSOR
    ) AS
    BEGIN
        OPEN P_RESULTADOS_RC FOR
            SELECT
                NRO_JIRA,
                NRO_ITEM,
                NOM_OBJETO,
                USU_IMPLEMENTACION,
                FEC_IMPLEMENTACION,
                HOR_IMPLEMENTACION,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION
            FROM
                IT.BA_LOG_OBJ_MODIFICADOS
            WHERE
                NRO_JIRA = P_NRO_JIRA
            ORDER BY
                NRO_ITEM;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099,
                'Error general en PAB_OBJ.P_CONSULTAR_POR_JIRA (Tabla: BA_LOG_OBJ_MODIFICADOS) para JIRA: ' || P_NRO_JIRA ||
                '. Error Oracle: ' || SQLERRM);
    END P_CONSULTAR_POR_JIRA;
    
    --------------------------------------------------------------------------
    PROCEDURE P_CONSULTAR_POR_PK (
        P_NRO_JIRA           IN  IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE,
        P_NRO_ITEM           IN  IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE,
        P_NOM_OBJETO         OUT IT.BA_LOG_OBJ_MODIFICADOS.NOM_OBJETO%TYPE,
        P_USU_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.USU_IMPLEMENTACION%TYPE,
        P_FEC_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.FEC_IMPLEMENTACION%TYPE,
        P_HOR_IMPLEMENTACION OUT IT.BA_LOG_OBJ_MODIFICADOS.HOR_IMPLEMENTACION%TYPE
    ) AS
    BEGIN
        SELECT
            NOM_OBJETO,
            USU_IMPLEMENTACION,
            FEC_IMPLEMENTACION,
            HOR_IMPLEMENTACION
        INTO
            P_NOM_OBJETO,
            P_USU_IMPLEMENTACION,
            P_FEC_IMPLEMENTACION,
            P_HOR_IMPLEMENTACION
        FROM
            IT.BA_LOG_OBJ_MODIFICADOS
        WHERE
            NRO_JIRA = P_NRO_JIRA
            AND NRO_ITEM = P_NRO_ITEM;
            
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099,
                'Error general en PAB_OBJ.P_CONSULTAR_POR_PK (Tabla: BA_LOG_OBJ_MODIFICADOS) para JIRA: ' || P_NRO_JIRA ||
                '. Error Oracle: ' || SQLERRM);
    END P_CONSULTAR_POR_PK;

    --------------------------------------------------------------------------
    -- **** INICIO DEL NUEVO PROCEDIMIENTO ****
    --------------------------------------------------------------------------
    PROCEDURE P_CONSULTAR_POR_PARAMETRO (
        P_TIPO_CONSULTA   IN VARCHAR2,
        P_VALOR_BUSQUEDA  IN VARCHAR2,
        P_RESULTADO_RC    OUT SYS_REFCURSOR
    ) AS
        V_SQL          VARCHAR2(4000);
        V_TIPO_UPPER   VARCHAR2(20) := UPPER(P_TIPO_CONSULTA);
        
        -- Variables para el caso 'PK'
        V_JIRA         IT.BA_LOG_OBJ_MODIFICADOS.NRO_JIRA%TYPE;
        V_ITEM         IT.BA_LOG_OBJ_MODIFICADOS.NRO_ITEM%TYPE;
        V_POS_COMA     NUMBER;
        
    BEGIN
        -- Construimos la base de la consulta
        V_SQL := 'SELECT NRO_JIRA, NRO_ITEM, NOM_OBJETO, USU_IMPLEMENTACION, FEC_IMPLEMENTACION, ' ||
                 'HOR_IMPLEMENTACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION ' ||
                 'FROM IT.BA_LOG_OBJ_MODIFICADOS ';

        -- Añadimos el filtro (WHERE) dinámicamente
        -- Usamos SQL dinámico con "bind variables" (:1, :2) para evitar SQL Injection.
        
        IF V_TIPO_UPPER = 'JIRA' THEN
            V_SQL := V_SQL || 'WHERE NRO_JIRA = :1 ORDER BY NRO_ITEM';
            OPEN P_RESULTADO_RC FOR V_SQL USING P_VALOR_BUSQUEDA;

        ELSIF V_TIPO_UPPER = 'OBJETO' THEN
            V_SQL := V_SQL || 'WHERE NOM_OBJETO = :1 ORDER BY NRO_JIRA, NRO_ITEM';
            OPEN P_RESULTADO_RC FOR V_SQL USING P_VALOR_BUSQUEDA;

        ELSIF V_TIPO_UPPER = 'USUARIO' THEN
            V_SQL := V_SQL || 'WHERE USU_IMPLEMENTACION = :1 ORDER BY NRO_JIRA, NRO_ITEM';
            OPEN P_RESULTADO_RC FOR V_SQL USING P_VALOR_BUSQUEDA;
            
        ELSIF V_TIPO_UPPER = 'PK' THEN
            -- Para 'PK', esperamos un formato "JIRA,ITEM" (ej: "PROY-123,1")
            V_POS_COMA := INSTR(P_VALOR_BUSQUEDA, ',');
            
            IF V_POS_COMA = 0 THEN
                 RAISE_APPLICATION_ERROR(-20010, 'Para consulta tipo "PK", P_VALOR_BUSQUEDA debe tener el formato "NRO_JIRA,NRO_ITEM".');
            END IF;
            
            -- Separamos los dos valores
            V_JIRA := SUBSTR(P_VALOR_BUSQUEDA, 1, V_POS_COMA - 1);
            V_ITEM := TO_NUMBER(SUBSTR(P_VALOR_BUSQUEDA, V_POS_COMA + 1));
            
            V_SQL := V_SQL || 'WHERE NRO_JIRA = :1 AND NRO_ITEM = :2';
            OPEN P_RESULTADO_RC FOR V_SQL USING V_JIRA, V_ITEM;

        ELSE
            RAISE_APPLICATION_ERROR(-20011, 'Tipo de consulta no válido: ' || P_TIPO_CONSULTA || '. Use "JIRA", "PK", "OBJETO" o "USUARIO".');
        END IF;

    EXCEPTION
        WHEN VALUE_ERROR THEN -- Error si el TO_NUMBER falla en el caso 'PK'
            RAISE_APPLICATION_ERROR(-20012, 'Error al procesar valor de "PK". Asegúrese que el formato sea "TEXTO,NUMERO". Valor recibido: ' || P_VALOR_BUSQUEDA);
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099, 'Error general en P_CONSULTAR_POR_PARAMETRO (Tipo: ' || P_TIPO_CONSULTA || '). Error Oracle: ' || SQLERRM);
    END P_CONSULTAR_POR_PARAMETRO;
    
END PAB_OBJ;
--

CREATE PUBLIC SYNONYM PAB_OBJ for it.PAB_OBJ;
GRANT EXECUTE ON PAB_OBJ to IT_TEMPORAL;

