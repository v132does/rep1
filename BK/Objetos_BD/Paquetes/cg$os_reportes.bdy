CREATE OR REPLACE PACKAGE BODY IT.cg$OS_REPORTES IS


PROCEDURE   validate_mandatory(cg$val_rec IN cg$row_type,
                               loc        IN VARCHAR2 DEFAULT '');
PROCEDURE   up_autogen_columns(cg$rec    IN OUT cg$row_type,
                               cg$ind    IN OUT cg$ind_type,
                               operation IN VARCHAR2 DEFAULT 'INS',
                               do_denorm IN BOOLEAN DEFAULT TRUE);
PROCEDURE   err_msg(msg  IN VARCHAR2,
                    type IN INTEGER,
                    loc  IN VARCHAR2 DEFAULT '');

--------------------------------------------------------------------------------
-- Name:        raise_uk_not_updateable
--
-- Description: Raise appropriate error when unique key updated
--
-- Parameters:  none
--------------------------------------------------------------------------------
PROCEDURE raise_uk_not_updateable(uk IN VARCHAR2) IS
BEGIN
    cg$errors.push(cg$errors.MsgGetText(cg$errors.API_UNIQUE_KEY_UPDATE, cg$errors.ERR_UK_UPDATE, uk),
                   'E',
                   'API',
                   cg$errors.API_UNIQUE_KEY_UPDATE,
                   'cg$OS_REPORTES.raise_uk_not_updateable');
                   cg$errors.raise_failure;
END raise_uk_not_updateable;


--------------------------------------------------------------------------------
-- Name:        raise_fk_not_transferable
--
-- Description: Raise appropriate error when foreign key updated
--
-- Parameters:  none
--------------------------------------------------------------------------------
PROCEDURE raise_fk_not_transferable(fk IN VARCHAR2) IS
BEGIN
    cg$errors.push(cg$errors.MsgGetText(cg$errors.API_FOREIGN_KEY_TRANS, cg$errors.ERR_FK_TRANS, fk),
                   'E',
                   'API',
                   cg$errors.API_FOREIGN_KEY_TRANS,
                   'cg$OS_REPORTES.raise_fk_not_transferable');
    cg$errors.raise_failure;
END raise_fk_not_transferable;


--------------------------------------------------------------------------------
-- Name:        up_autogen_columns
--
-- Description: Specific autogeneration of column values and conversion to
--              uppercase
--
-- Parameters:  cg$rec    Record of row to be manipulated
--              cg$ind    Indicators for row
--              operation Procedure where this procedure was called
--------------------------------------------------------------------------------
PROCEDURE up_autogen_columns(cg$rec IN OUT cg$row_type,
                             cg$ind IN OUT cg$ind_type,
                             operation IN VARCHAR2 DEFAULT 'INS',
                             do_denorm IN BOOLEAN DEFAULT TRUE) IS
BEGIN
  IF (operation = 'INS') THEN
    BEGIN  -- Server Defaulted Sequence in Parent
      IF (cg$ind.NRO_REPORTE = FALSE
      OR  cg$rec.NRO_REPORTE is NULL) THEN
        SELECT NVL(MAX(NRO_REPORTE), 0) + 1
        INTO   cg$rec.NRO_REPORTE
        FROM   OS_REPORTES
        WHERE
         (    cg$rec.COD_ENTE = COD_ENTE
         AND  cg$rec.SECUENCIA = SECUENCIA )  -- Primary Key columns

        ;
      END IF;
    EXCEPTION WHEN others THEN
      cg$errors.push(SQLERRM, 'E', 'ORA', SQLCODE,
                     'cg$OS_REPORTES.up_autogen_seq_in_parent.NRO_REPORTE.OTHERS');
      cg$errors.raise_failure;
    END;
    BEGIN  -- Server Defaulted Sequence in Parent
      IF (cg$ind.SECUENCIA = FALSE
      OR  cg$rec.SECUENCIA is NULL) THEN
        SELECT NVL(MAX(SECUENCIA), 0) + 1
        INTO   cg$rec.SECUENCIA
        FROM   OS_REPORTES
        WHERE
         (    cg$rec.COD_ENTE = COD_ENTE
         AND  cg$rec.NRO_REPORTE = NRO_REPORTE )  -- Primary Key columns

        ;
      END IF;
    EXCEPTION WHEN others THEN
      cg$errors.push(SQLERRM, 'E', 'ORA', SQLCODE,
                     'cg$OS_REPORTES.up_autogen_seq_in_parent.SECUENCIA.OTHERS');
      cg$errors.raise_failure;
    END;
    NULL;
  ELSE      -- (operation = 'UPD')
    NULL;
  END IF;   -- (operation = 'INS') ELSE (operation = 'UPD')

  -- Statements executed for both 'INS' and 'UPD'


EXCEPTION
  WHEN no_data_found THEN
    NULL;
  WHEN others THEN
    cg$errors.push( SQLERRM, 'E', 'ORA', SQLCODE,
                    'cg$OS_REPORTES.up_autogen_columns');
    cg$errors.raise_failure;
END up_autogen_columns;


--------------------------------------------------------------------------------
-- Name:        validate_mandatory
--
-- Description: Checks all mandatory columns are not null and raises appropriate
--              error if not satisfied
--
-- Parameters:  cg$val_rec Record of row to be checked
--              loc        Place where this procedure was called for error
--                         trapping
--------------------------------------------------------------------------------
PROCEDURE validate_mandatory(cg$val_rec IN cg$row_type,
                             loc        IN VARCHAR2 DEFAULT '') IS
BEGIN
    IF (cg$val_rec.COD_ENTE IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P10COD_ENTE),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.NRO_REPORTE IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P20NRO_REPORTE),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.SECUENCIA IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P30SECUENCIA),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.TIP_REPORTE IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P50TIP_REPORTE),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.TIP_ACTIVIDAD IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P60TIP_ACTIVIDAD),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.FEC_INGRESO IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P70FEC_INGRESO),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.EST_REPORTE IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P80EST_REPORTE),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.USU_INSERCION IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P120USU_INSERCION),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.FEC_INSERCION IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P130FEC_INSERCION),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.USU_MODIFICACION IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P140USU_MODIFICACION),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    IF (cg$val_rec.FEC_MODIFICACION IS NULL) THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_MAND_COLUMN_ISNULL, cg$errors.VAL_MAND, P150FEC_MODIFICACION),
                       'E',
                       'API',
                       cg$errors.API_MAND_COLUMN_ISNULL,
                       loc);
    END IF;
    NULL;
END validate_mandatory;


--------------------------------------------------------------------------------
-- Name:        validate_foreign_keys
--
-- Description: Checks all mandatory columns are not null and raises appropriate
--              error if not satisfied
--
-- Parameters:  cg$rec Record of row to be checked
--------------------------------------------------------------------------------
PROCEDURE validate_foreign_keys_ins(cg$rec IN cg$row_type) IS
    fk_check INTEGER;
BEGIN
NULL;
END;

PROCEDURE validate_foreign_keys_upd( cg$rec IN cg$row_type,
                                     cg$old_rec IN cg$row_type,
                                     cg$ind IN cg$ind_type) IS
    fk_check INTEGER;
BEGIN
NULL;
END;

PROCEDURE validate_foreign_keys_del(cg$rec IN cg$row_type) IS
    fk_check INTEGER;
BEGIN
NULL;
END;


--------------------------------------------------------------------------------
-- Name:        slct
--
-- Description: Selects into the given parameter all the attributes for the row
--              given by the primary key
--
-- Parameters:  cg$sel_rec  Record of row to be selected into using its PK
--------------------------------------------------------------------------------
PROCEDURE slct(cg$sel_rec IN OUT cg$row_type) IS

BEGIN

    IF cg$sel_rec.the_rowid is null THEN
       SELECT    COD_ENTE
       ,         NRO_REPORTE
       ,         SECUENCIA
       ,         DES_BREVE
       ,         TIP_REPORTE
       ,         TIP_ACTIVIDAD
       ,         FEC_INGRESO
       ,         EST_REPORTE
       ,         FEC_ENVIO
       ,         DES_DETALLADA
       ,         TIPOLOGIA
       ,         USU_INSERCION
       ,         FEC_INSERCION
       ,         USU_MODIFICACION
       ,         FEC_MODIFICACION
       , rowid
       INTO      cg$sel_rec.COD_ENTE
       ,         cg$sel_rec.NRO_REPORTE
       ,         cg$sel_rec.SECUENCIA
       ,         cg$sel_rec.DES_BREVE
       ,         cg$sel_rec.TIP_REPORTE
       ,         cg$sel_rec.TIP_ACTIVIDAD
       ,         cg$sel_rec.FEC_INGRESO
       ,         cg$sel_rec.EST_REPORTE
       ,         cg$sel_rec.FEC_ENVIO
       ,         cg$sel_rec.DES_DETALLADA
       ,         cg$sel_rec.TIPOLOGIA
       ,         cg$sel_rec.USU_INSERCION
       ,         cg$sel_rec.FEC_INSERCION
       ,         cg$sel_rec.USU_MODIFICACION
       ,         cg$sel_rec.FEC_MODIFICACION
       ,cg$sel_rec.the_rowid
       FROM   OS_REPORTES
       WHERE        COD_ENTE = cg$sel_rec.COD_ENTE
       AND       NRO_REPORTE = cg$sel_rec.NRO_REPORTE
       AND       SECUENCIA = cg$sel_rec.SECUENCIA;
    ELSE
       SELECT    COD_ENTE
       ,         NRO_REPORTE
       ,         SECUENCIA
       ,         DES_BREVE
       ,         TIP_REPORTE
       ,         TIP_ACTIVIDAD
       ,         FEC_INGRESO
       ,         EST_REPORTE
       ,         FEC_ENVIO
       ,         DES_DETALLADA
       ,         TIPOLOGIA
       ,         USU_INSERCION
       ,         FEC_INSERCION
       ,         USU_MODIFICACION
       ,         FEC_MODIFICACION
       , rowid
       INTO      cg$sel_rec.COD_ENTE
       ,         cg$sel_rec.NRO_REPORTE
       ,         cg$sel_rec.SECUENCIA
       ,         cg$sel_rec.DES_BREVE
       ,         cg$sel_rec.TIP_REPORTE
       ,         cg$sel_rec.TIP_ACTIVIDAD
       ,         cg$sel_rec.FEC_INGRESO
       ,         cg$sel_rec.EST_REPORTE
       ,         cg$sel_rec.FEC_ENVIO
       ,         cg$sel_rec.DES_DETALLADA
       ,         cg$sel_rec.TIPOLOGIA
       ,         cg$sel_rec.USU_INSERCION
       ,         cg$sel_rec.FEC_INSERCION
       ,         cg$sel_rec.USU_MODIFICACION
       ,         cg$sel_rec.FEC_MODIFICACION
       ,cg$sel_rec.the_rowid
       FROM   OS_REPORTES
       WHERE  rowid = cg$sel_rec.the_rowid;
    END IF;

EXCEPTION WHEN OTHERS THEN
    cg$errors.push(SQLERRM,
                   'E',
                   'ORA',
                   SQLCODE,
                   'cg$OS_REPORTES.slct.others');
    cg$errors.raise_failure;

END slct;


--------------------------------------------------------------------------------
-- Name:        cascade_update
--
-- Description: Updates all child tables affected by a change to OS_REPORTES
--
-- Parameters:  cg$rec     Record of OS_REPORTES current values
--              cg$old_rec Record of OS_REPORTES previous values
--------------------------------------------------------------------------------
PROCEDURE cascade_update(cg$new_rec IN OUT cg$row_type,
                         cg$old_rec IN     cg$row_type) IS
BEGIN
  NULL;
END cascade_update;


--------------------------------------------------------------------------------
-- Name:        validate_domain_cascade_update
--
-- Description: Implement the Domain Key Constraint Cascade Updates Resticts rule
--              of each child table that references this tableOS_REPORTES
--
-- Parameters:  cg$old_rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE validate_domain_cascade_update( cg$old_rec IN cg$row_type ) IS
  dk_check INTEGER;
BEGIN
  NULL;
END validate_domain_cascade_update;


-----------------------------------------------------------------------------------------
-- Name:        domain_cascade_update
--
-- Description: Implement the Domain Key Constraint Cascade Updates rules of each
--              child table that references this table OS_REPORTES
--
-- Parameters:  cg$new_rec  New values for OS_REPORTES's domain key constraint columns
--              cg$new_ind  Indicates changed OS_REPORTES's domain key constraint columns
--              cg$old_rec  Current values for OS_REPORTES's domain key constraint columns
-----------------------------------------------------------------------------------------
PROCEDURE domain_cascade_update(cg$new_rec IN OUT cg$row_type,
                                cg$new_ind IN OUT cg$ind_type,
                                cg$old_rec IN     cg$row_type) IS
BEGIN
  NULL;
END domain_cascade_update;


--------------------------------------------------------------------------------
-- Name:        cascade_delete
--
-- Description: Delete all child tables affected by a delete to OS_REPORTES
--
-- Parameters:  cg$rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE cascade_delete(cg$old_rec IN OUT cg$row_type)
IS
BEGIN
  NULL;
END cascade_delete;

--------------------------------------------------------------------------------
-- Name:        domain_cascade_delete
--
-- Description: Implement the Domain Key Constraint Cascade Delete rules of each
--              child table that references this tableOS_REPORTES
--
-- Parameters:  cg$old_rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE domain_cascade_delete( cg$old_rec IN cg$row_type )
IS
BEGIN
  NULL;
END domain_cascade_delete;


--------------------------------------------------------------------------------
-- Name:        validate_domain_cascade_delete
--
-- Description: Implement the Domain Key Constraint Cascade Delete Restricts rule
--              of each child table that references this tableOS_REPORTES
--
-- Parameters:  cg$old_rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE validate_domain_cascade_delete(cg$old_rec IN cg$row_type)
IS
    dk_check INTEGER;
BEGIN
  NULL;
END validate_domain_cascade_delete;



--------------------------------------------------------------------------------
-- Name:        validate_arc
--
-- Description: Checks for adherence to arc relationship
--
-- Parameters:  cg$rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE validate_arc(cg$rec IN OUT cg$row_type) IS
i NUMBER;
BEGIN
    NULL;
END validate_arc;


--------------------------------------------------------------------------------
-- Name:        validate_domain
--
-- Description: Checks against reference table for values lying in a domain
--
-- Parameters:  cg$rec     Record of OS_REPORTES current values
--------------------------------------------------------------------------------
PROCEDURE validate_domain(cg$rec IN OUT cg$row_type,
                          cg$ind IN cg$ind_type DEFAULT cg$ind_true)
IS
  dummy NUMBER;
  found BOOLEAN;
  no_tabview EXCEPTION;
  PRAGMA EXCEPTION_INIT(no_tabview, -942);
BEGIN





    found := false;
    IF (cg$ind.TIP_REPORTE AND cg$rec.TIP_REPORTE IS NOT NULL) THEN
      FOR c IN (SELECT RV_LOW_VALUE, RV_HIGH_VALUE FROM CG_REF_CODES WHERE RV_DOMAIN = 'TIP_REPORTE' )
      LOOP
         IF (    c.RV_HIGH_VALUE IS NULL
             AND cg$rec.TIP_REPORTE = c.RV_LOW_VALUE )
         OR (    c.RV_HIGH_VALUE IS NOT NULL
             AND cg$rec.TIP_REPORTE BETWEEN c.RV_LOW_VALUE AND c.RV_HIGH_VALUE )
         THEN
           found := true;
           EXIT;
         END IF;
      END LOOP;

      IF ( NOT found ) THEN
        cg$errors.push( cg$errors.MsgGetText(cg$errors.API_RV_LOOKUP_FAIL,
                                             cg$errors.APIMSG_RV_LOOKUP_FAIL,
                                             cg$rec.TIP_REPORTE,'OS_REPORTES','TIP_REPORTE'),
                        'E',
                        'API',
                        cg$errors.API_RV_LOOKUP_FAIL,
                        'cg$OS_REPORTES.v_domain.no_data_found' );
        cg$errors.raise_failure;
      END IF;
    END IF;

    found := false;
    IF (cg$ind.TIP_ACTIVIDAD AND cg$rec.TIP_ACTIVIDAD IS NOT NULL) THEN
      FOR c IN (SELECT RV_LOW_VALUE, RV_HIGH_VALUE FROM CG_REF_CODES WHERE RV_DOMAIN = 'TIP_ACT_REPORTE' )
      LOOP
         IF (    c.RV_HIGH_VALUE IS NULL
             AND cg$rec.TIP_ACTIVIDAD = c.RV_LOW_VALUE )
         OR (    c.RV_HIGH_VALUE IS NOT NULL
             AND cg$rec.TIP_ACTIVIDAD BETWEEN c.RV_LOW_VALUE AND c.RV_HIGH_VALUE )
         THEN
           found := true;
           EXIT;
         END IF;
      END LOOP;

      IF ( NOT found ) THEN
        cg$errors.push( cg$errors.MsgGetText(cg$errors.API_RV_LOOKUP_FAIL,
                                             cg$errors.APIMSG_RV_LOOKUP_FAIL,
                                             cg$rec.TIP_ACTIVIDAD,'OS_REPORTES','TIP_ACTIVIDAD'),
                        'E',
                        'API',
                        cg$errors.API_RV_LOOKUP_FAIL,
                        'cg$OS_REPORTES.v_domain.no_data_found' );
        cg$errors.raise_failure;
      END IF;
    END IF;


    found := false;
    IF (cg$ind.EST_REPORTE AND cg$rec.EST_REPORTE IS NOT NULL) THEN
      FOR c IN (SELECT RV_LOW_VALUE, RV_HIGH_VALUE FROM CG_REF_CODES WHERE RV_DOMAIN = 'EST_REPORTE' )
      LOOP
         IF (    c.RV_HIGH_VALUE IS NULL
             AND cg$rec.EST_REPORTE = c.RV_LOW_VALUE )
         OR (    c.RV_HIGH_VALUE IS NOT NULL
             AND cg$rec.EST_REPORTE BETWEEN c.RV_LOW_VALUE AND c.RV_HIGH_VALUE )
         THEN
           found := true;
           EXIT;
         END IF;
      END LOOP;

      IF ( NOT found ) THEN
        cg$errors.push( cg$errors.MsgGetText(cg$errors.API_RV_LOOKUP_FAIL,
                                             cg$errors.APIMSG_RV_LOOKUP_FAIL,
                                             cg$rec.EST_REPORTE,'OS_REPORTES','EST_REPORTE'),
                        'E',
                        'API',
                        cg$errors.API_RV_LOOKUP_FAIL,
                        'cg$OS_REPORTES.v_domain.no_data_found' );
        cg$errors.raise_failure;
      END IF;
    END IF;









    NULL;

EXCEPTION
    WHEN cg$errors.cg$error THEN
        cg$errors.raise_failure;
    WHEN no_tabview THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_RV_TAB_NOT_FOUND,
                                            cg$errors.APIMSG_RV_TAB_NOT_FOUND,
                                            'CG_REF_CODES','OS_REPORTES'),
                       'E',
                       'API',
                       cg$errors.API_RV_TAB_NOT_FOUND,
                       'cg$OS_REPORTES.v_domain.no_reftable_found');
        cg$errors.raise_failure;
    WHEN OTHERS THEN
        cg$errors.push(SQLERRM,
                       'E',
                       'ORA',
                       SQLCODE,
                       'cg$OS_REPORTES.v_domain.others');
        cg$errors.raise_failure;
END validate_domain;


--------------------------------------------------------------------------------
-- Name:        err_msg
--
-- Description: Pushes onto stack appropriate user defined error message
--              depending on the rule violated
--
-- Parameters:  msg     Oracle error message
--              type    Type of violation e.g. check_constraint: ERR_CHECK_CON
--              loc     Place where this procedure was called for error
--                      trapping
--------------------------------------------------------------------------------
PROCEDURE err_msg(msg   IN VARCHAR2,
                  type  IN INTEGER,
                  loc   IN VARCHAR2 DEFAULT '') IS
con_name VARCHAR2(240);
BEGIN
    con_name := cg$errors.parse_constraint(msg, type);
    IF (con_name = 'PK_OS_REPORTES') THEN
        cg$errors.push(nvl(PK_OS_REPORTES
                  ,cg$errors.MsgGetText(cg$errors.API_PK_CON_VIOLATED
					                 ,cg$errors.APIMSG_PK_VIOLAT
                                     ,'PK_OS_REPORTES'
                                     ,'OS_REPORTES')),
                       'E',
                       'API',
                       cg$errors.API_PK_CON_VIOLATED,
                       loc);
    ELSIF (con_name = 'CC_OREPO_SEC_TIP_REPORTE' AND CC_OREPO_SEC_TIP_REPORTE IS NOT NULL) THEN
        cg$errors.push('Tipo de Reporte Inicial solo puede registrarse con la primera Sec.',
                       'E',
                       'API',
                       cg$errors.API_CK_CON_VIOLATED,
                       loc);

    ELSIF (con_name = 'FK_OREPO_COD_ENTE') THEN
        cg$errors.push(nvl(FK_OREPO_COD_ENTE
                      ,cg$errors.MsgGetText(cg$errors.API_FK_CON_VIOLATED
					                 ,cg$errors.APIMSG_FK_VIOLAT
                                     ,'FK_OREPO_COD_ENTE'
                                     ,'OS_REPORTES')),
                       'E',
                       'API',
                       cg$errors.API_FK_CON_VIOLATED,
                       loc);
    ELSE
        cg$errors.push(SQLERRM,
                       'E',
                       'ORA',
                       SQLCODE,
                       loc);
    END IF;
END err_msg;




--------------------------------------------------------------------------------
-- Name:        doLobs
--
-- Description: This function is updating lob columns
--
-- Parameters:  cg$rec  Record of row to be inserted
--              cg$ind  Record of columns specifically set
--------------------------------------------------------------------------------
PROCEDURE doLobs(cg$rec IN OUT cg$row_type,
                 cg$ind IN OUT cg$ind_type) IS
BEGIN
   NULL;
END doLobs;


--------------------------------------------------------------------------------
-- Name:        ins
--
-- Description: API insert procedure
--
-- Parameters:  cg$rec  Record of row to be inserted
--              cg$ind  Record of columns specifically set
--              do_ins  Whether we want the actual INSERT to occur
--------------------------------------------------------------------------------
PROCEDURE ins(cg$rec IN OUT cg$row_type,
              cg$ind IN OUT cg$ind_type,
              do_ins IN BOOLEAN DEFAULT TRUE) IS
cg$tmp_rec cg$row_type;

--  Constant default values

D80_EST_REPORTE CONSTANT OS_REPORTES.EST_REPORTE%TYPE := 'P';
D120_USU_INSERCION CONSTANT OS_REPORTES.USU_INSERCION%TYPE := USER;
D130_FEC_INSERCION CONSTANT OS_REPORTES.FEC_INSERCION%TYPE := SYSDATE;
D140_USU_MODIFICACION CONSTANT OS_REPORTES.USU_MODIFICACION%TYPE := USER;
D150_FEC_MODIFICACION CONSTANT OS_REPORTES.FEC_MODIFICACION%TYPE := SYSDATE;

BEGIN
--  Application_logic Pre-Insert <<Start>>
--  Application_logic Pre-Insert << End >>

--  Defaulted

    IF NOT (cg$ind.EST_REPORTE) THEN cg$rec.EST_REPORTE := D80_EST_REPORTE; END IF;
    IF NOT (cg$ind.USU_INSERCION) THEN cg$rec.USU_INSERCION := D120_USU_INSERCION; END IF;
    IF NOT (cg$ind.FEC_INSERCION) THEN cg$rec.FEC_INSERCION := D130_FEC_INSERCION; END IF;
    IF NOT (cg$ind.USU_MODIFICACION) THEN cg$rec.USU_MODIFICACION := D140_USU_MODIFICACION; END IF;
    IF NOT (cg$ind.FEC_MODIFICACION) THEN cg$rec.FEC_MODIFICACION := D150_FEC_MODIFICACION; END IF;
--  Auto-generated and uppercased columns

    up_autogen_columns(cg$rec, cg$ind, 'INS', do_ins);

    called_from_package := TRUE;

    IF (do_ins) THEN
        validate_foreign_keys_ins(cg$rec);
        validate_arc(cg$rec);
        validate_domain(cg$rec);

        INSERT INTO OS_REPORTES
            (COD_ENTE
            ,NRO_REPORTE
            ,SECUENCIA
            ,DES_BREVE
            ,TIP_REPORTE
            ,TIP_ACTIVIDAD
            ,FEC_INGRESO
            ,EST_REPORTE
            ,FEC_ENVIO
            ,DES_DETALLADA
            ,TIPOLOGIA
            ,USU_INSERCION
            ,FEC_INSERCION
            ,USU_MODIFICACION
            ,FEC_MODIFICACION)
        VALUES
            (cg$rec.COD_ENTE
            ,cg$rec.NRO_REPORTE
            ,cg$rec.SECUENCIA
            ,cg$rec.DES_BREVE
            ,cg$rec.TIP_REPORTE
            ,cg$rec.TIP_ACTIVIDAD
            ,cg$rec.FEC_INGRESO
            ,cg$rec.EST_REPORTE
            ,cg$rec.FEC_ENVIO
            ,cg$rec.DES_DETALLADA
            ,cg$rec.TIPOLOGIA
            ,cg$rec.USU_INSERCION
            ,cg$rec.FEC_INSERCION
            ,cg$rec.USU_MODIFICACION
            ,cg$rec.FEC_MODIFICACION
);
        doLobs(cg$rec, cg$ind);
        slct(cg$rec);

        upd_oper_denorm2(cg$rec, cg$tmp_rec, cg$ind, 'INS');
    END IF;

    called_from_package := FALSE;



--  Application logic Post-Insert <<Start>>
--  Application logic Post-Insert << End >>

EXCEPTION
    WHEN cg$errors.cg$error THEN
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.mandatory_missing THEN
        validate_mandatory(cg$rec, 'cg$OS_REPORTES.ins.mandatory_missing');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.check_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_CHECK_CON, 'cg$OS_REPORTES.ins.check_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.fk_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_FOREIGN_KEY, 'cg$OS_REPORTES.ins.fk_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.uk_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_UNIQUE_KEY, 'cg$OS_REPORTES.ins.uk_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN OTHERS THEN
        cg$errors.push(SQLERRM,
                       'E',
                       'ORA',
                       SQLCODE,
                       'cg$OS_REPORTES.ins.others');
        called_from_package := FALSE;
        cg$errors.raise_failure;
END ins;


--------------------------------------------------------------------------------
-- Name:        upd
--
-- Description: API update procedure
--
-- Parameters:  cg$rec  Record of row to be updated
--              cg$ind  Record of columns specifically set
--              do_upd  Whether we want the actual UPDATE to occur
--------------------------------------------------------------------------------
PROCEDURE upd(cg$rec             IN OUT cg$row_type,
              cg$ind             IN OUT cg$ind_type,
              do_upd             IN BOOLEAN DEFAULT TRUE,
              cg$pk              IN cg$row_type DEFAULT NULL )
IS
  cg$upd_rec    cg$row_type;
  cg$old_rec    cg$row_type;
  RECORD_LOGGED BOOLEAN := FALSE;
BEGIN
--  Application_logic Pre-Update <<Start>>
--  Application_logic Pre-Update << End >>


    IF ( cg$pk.COD_ENTE IS NULL ) THEN
      cg$upd_rec.COD_ENTE := cg$rec.COD_ENTE;
    ELSE
      cg$upd_rec.COD_ENTE := cg$pk.COD_ENTE;
    END IF;
    cg$old_rec.COD_ENTE := cg$upd_rec.COD_ENTE;
    IF ( cg$pk.NRO_REPORTE IS NULL ) THEN
      cg$upd_rec.NRO_REPORTE := cg$rec.NRO_REPORTE;
    ELSE
      cg$upd_rec.NRO_REPORTE := cg$pk.NRO_REPORTE;
    END IF;
    cg$old_rec.NRO_REPORTE := cg$upd_rec.NRO_REPORTE;
    IF ( cg$pk.SECUENCIA IS NULL ) THEN
      cg$upd_rec.SECUENCIA := cg$rec.SECUENCIA;
    ELSE
      cg$upd_rec.SECUENCIA := cg$pk.SECUENCIA;
    END IF;
    cg$old_rec.SECUENCIA := cg$upd_rec.SECUENCIA;

    IF ( cg$pk.the_rowid IS NULL ) THEN
      cg$upd_rec.the_rowid := cg$rec.the_rowid;
    ELSE
      cg$upd_rec.the_rowid := cg$pk.the_rowid;
    END IF;
    cg$old_rec.the_rowid := cg$upd_rec.the_rowid;

    IF ( do_upd ) THEN

        slct(cg$upd_rec);


        --  Report error if attempt to update non updateable Primary Key PK_OS_REPORTES
        IF (cg$ind.COD_ENTE AND cg$rec.COD_ENTE != cg$upd_rec.COD_ENTE) THEN
            raise_uk_not_updateable('PK_OS_REPORTES');
        END IF;
        IF (cg$ind.NRO_REPORTE AND cg$rec.NRO_REPORTE != cg$upd_rec.NRO_REPORTE) THEN
            raise_uk_not_updateable('PK_OS_REPORTES');
        END IF;
        IF (cg$ind.SECUENCIA AND cg$rec.SECUENCIA != cg$upd_rec.SECUENCIA) THEN
            raise_uk_not_updateable('PK_OS_REPORTES');
        END IF;
        IF NOT (cg$ind.COD_ENTE) THEN
            cg$rec.COD_ENTE := cg$upd_rec.COD_ENTE;
        END IF;
        IF NOT (cg$ind.NRO_REPORTE) THEN
            cg$rec.NRO_REPORTE := cg$upd_rec.NRO_REPORTE;
        END IF;
        IF NOT (cg$ind.SECUENCIA) THEN
            cg$rec.SECUENCIA := cg$upd_rec.SECUENCIA;
        END IF;
        IF NOT (cg$ind.DES_BREVE) THEN
            cg$rec.DES_BREVE := cg$upd_rec.DES_BREVE;
        END IF;
        IF NOT (cg$ind.TIP_REPORTE) THEN
            cg$rec.TIP_REPORTE := cg$upd_rec.TIP_REPORTE;
        END IF;
        IF NOT (cg$ind.TIP_ACTIVIDAD) THEN
            cg$rec.TIP_ACTIVIDAD := cg$upd_rec.TIP_ACTIVIDAD;
        END IF;
        IF NOT (cg$ind.FEC_INGRESO) THEN
            cg$rec.FEC_INGRESO := cg$upd_rec.FEC_INGRESO;
        END IF;
        IF NOT (cg$ind.EST_REPORTE) THEN
            cg$rec.EST_REPORTE := cg$upd_rec.EST_REPORTE;
        END IF;
        IF NOT (cg$ind.FEC_ENVIO) THEN
            cg$rec.FEC_ENVIO := cg$upd_rec.FEC_ENVIO;
        END IF;
        IF NOT (cg$ind.DES_DETALLADA) THEN
            cg$rec.DES_DETALLADA := cg$upd_rec.DES_DETALLADA;
        END IF;
        IF NOT (cg$ind.TIPOLOGIA) THEN
            cg$rec.TIPOLOGIA := cg$upd_rec.TIPOLOGIA;
        END IF;
        IF NOT (cg$ind.USU_INSERCION) THEN
            cg$rec.USU_INSERCION := cg$upd_rec.USU_INSERCION;
        END IF;
        IF NOT (cg$ind.FEC_INSERCION) THEN
            cg$rec.FEC_INSERCION := cg$upd_rec.FEC_INSERCION;
        END IF;
        IF NOT (cg$ind.USU_MODIFICACION) THEN
            cg$rec.USU_MODIFICACION := cg$upd_rec.USU_MODIFICACION;
        END IF;
        IF NOT (cg$ind.FEC_MODIFICACION) THEN
            cg$rec.FEC_MODIFICACION := cg$upd_rec.FEC_MODIFICACION;
        END IF;
    ELSE
	     -- Perform checks if called from a trigger
	     -- Indicators are only set on changed values
	     null;
        --  Report error if attempt to update non updateable Primary Key PK_OS_REPORTES
        IF ( cg$ind.COD_ENTE
        OR   cg$ind.NRO_REPORTE
        OR   cg$ind.SECUENCIA ) THEN
          raise_uk_not_updateable('PK_OS_REPORTES');
        END IF;
    END IF;

    up_autogen_columns(cg$rec, cg$ind, 'UPD', do_upd);  --  Auto-generated and uppercased columns

--  Now do update if updateable columns exist
    IF (do_upd) THEN
        DECLARE
            called_from BOOLEAN := called_from_package;
        BEGIN
          called_from_package := TRUE;

          slct(cg$old_rec);
          validate_foreign_keys_upd(cg$rec, cg$old_rec, cg$ind);
          validate_arc(cg$rec);
          validate_domain(cg$rec, cg$ind);
          validate_domain_cascade_update(cg$old_rec);

          IF cg$rec.the_rowid is null THEN
            UPDATE OS_REPORTES
            SET
              DES_BREVE = cg$rec.DES_BREVE
              ,TIP_REPORTE = cg$rec.TIP_REPORTE
              ,TIP_ACTIVIDAD = cg$rec.TIP_ACTIVIDAD
              ,FEC_INGRESO = cg$rec.FEC_INGRESO
              ,EST_REPORTE = cg$rec.EST_REPORTE
              ,FEC_ENVIO = cg$rec.FEC_ENVIO
              ,DES_DETALLADA = cg$rec.DES_DETALLADA
              ,TIPOLOGIA = cg$rec.TIPOLOGIA
              ,USU_INSERCION = cg$rec.USU_INSERCION
              ,FEC_INSERCION = cg$rec.FEC_INSERCION
              ,USU_MODIFICACION = cg$rec.USU_MODIFICACION
              ,FEC_MODIFICACION = cg$rec.FEC_MODIFICACION
            WHERE  COD_ENTE = cg$rec.COD_ENTE
            AND    NRO_REPORTE = cg$rec.NRO_REPORTE
            AND    SECUENCIA = cg$rec.SECUENCIA;
            null;
          ELSE
            UPDATE OS_REPORTES
            SET
              DES_BREVE = cg$rec.DES_BREVE
              ,TIP_REPORTE = cg$rec.TIP_REPORTE
              ,TIP_ACTIVIDAD = cg$rec.TIP_ACTIVIDAD
              ,FEC_INGRESO = cg$rec.FEC_INGRESO
              ,EST_REPORTE = cg$rec.EST_REPORTE
              ,FEC_ENVIO = cg$rec.FEC_ENVIO
              ,DES_DETALLADA = cg$rec.DES_DETALLADA
              ,TIPOLOGIA = cg$rec.TIPOLOGIA
              ,USU_INSERCION = cg$rec.USU_INSERCION
              ,FEC_INSERCION = cg$rec.FEC_INSERCION
              ,USU_MODIFICACION = cg$rec.USU_MODIFICACION
              ,FEC_MODIFICACION = cg$rec.FEC_MODIFICACION
            WHERE rowid = cg$rec.the_rowid;

            null;
          END IF;

          slct(cg$rec);

          upd_denorm2(cg$rec, cg$ind);
          upd_oper_denorm2(cg$rec, cg$old_rec, cg$ind, 'UPD');
          cascade_update(cg$rec, cg$old_rec);
          domain_cascade_update(cg$rec, cg$ind, cg$old_rec);
          called_from_package := called_from;
        END;
    END IF;



    IF NOT (do_upd) THEN
        cg$table(idx).COD_ENTE := cg$rec.COD_ENTE;
        cg$tableind(idx).COD_ENTE := cg$ind.COD_ENTE;
        cg$table(idx).NRO_REPORTE := cg$rec.NRO_REPORTE;
        cg$tableind(idx).NRO_REPORTE := cg$ind.NRO_REPORTE;
        cg$table(idx).SECUENCIA := cg$rec.SECUENCIA;
        cg$tableind(idx).SECUENCIA := cg$ind.SECUENCIA;
        cg$table(idx).DES_BREVE := cg$rec.DES_BREVE;
        cg$tableind(idx).DES_BREVE := cg$ind.DES_BREVE;
        cg$table(idx).TIP_REPORTE := cg$rec.TIP_REPORTE;
        cg$tableind(idx).TIP_REPORTE := cg$ind.TIP_REPORTE;
        cg$table(idx).TIP_ACTIVIDAD := cg$rec.TIP_ACTIVIDAD;
        cg$tableind(idx).TIP_ACTIVIDAD := cg$ind.TIP_ACTIVIDAD;
        cg$table(idx).FEC_INGRESO := cg$rec.FEC_INGRESO;
        cg$tableind(idx).FEC_INGRESO := cg$ind.FEC_INGRESO;
        cg$table(idx).EST_REPORTE := cg$rec.EST_REPORTE;
        cg$tableind(idx).EST_REPORTE := cg$ind.EST_REPORTE;
        cg$table(idx).FEC_ENVIO := cg$rec.FEC_ENVIO;
        cg$tableind(idx).FEC_ENVIO := cg$ind.FEC_ENVIO;
        cg$table(idx).DES_DETALLADA := cg$rec.DES_DETALLADA;
        cg$tableind(idx).DES_DETALLADA := cg$ind.DES_DETALLADA;
        cg$table(idx).TIPOLOGIA := cg$rec.TIPOLOGIA;
        cg$tableind(idx).TIPOLOGIA := cg$ind.TIPOLOGIA;
        cg$table(idx).USU_INSERCION := cg$rec.USU_INSERCION;
        cg$tableind(idx).USU_INSERCION := cg$ind.USU_INSERCION;
        cg$table(idx).FEC_INSERCION := cg$rec.FEC_INSERCION;
        cg$tableind(idx).FEC_INSERCION := cg$ind.FEC_INSERCION;
        cg$table(idx).USU_MODIFICACION := cg$rec.USU_MODIFICACION;
        cg$tableind(idx).USU_MODIFICACION := cg$ind.USU_MODIFICACION;
        cg$table(idx).FEC_MODIFICACION := cg$rec.FEC_MODIFICACION;
        cg$tableind(idx).FEC_MODIFICACION := cg$ind.FEC_MODIFICACION;
        idx := idx + 1;
    END IF;

--  Application_logic Post-Update <<Start>>
--  Application_logic Post-Update << End >>

EXCEPTION
    WHEN cg$errors.cg$error THEN
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.upd_mandatory_null THEN
        validate_mandatory(cg$rec, 'cg$OS_REPORTES.upd.upd_mandatory_null');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.check_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_CHECK_CON, 'cg$OS_REPORTES.upd.check_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.fk_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_FOREIGN_KEY, 'cg$OS_REPORTES.upd.fk_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.uk_violation THEN
        err_msg(SQLERRM, cg$errors.ERR_UNIQUE_KEY, 'cg$OS_REPORTES.upd.uk_violation');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN OTHERS THEN
        cg$errors.push(SQLERRM,
                       'E',
                       'ORA',
                       SQLCODE,
                       'cg$OS_REPORTES.upd.others');
        called_from_package := FALSE;
        cg$errors.raise_failure;
END upd;


----------------------------------------------------------------------------------------
-- Name:        domain_cascade_upd
--
-- Description: Update the Domain Constraint Key columns of OS_REPORTES when the
--              Cascade Update rule is Cascades and the domain table has been
--              updated. Called from <Domain Table pkg>.domain_cascade_update().
--
-- Parameters:  cg$rec      New values for OS_REPORTES's domain key constraint columns
--              cg$ind      Indicates changed OS_REPORTES's domain key constraint columns
--              cg$old_rec  Current values for OS_REPORTES's domain key constraint columns
----------------------------------------------------------------------------------------
PROCEDURE   domain_cascade_upd( cg$rec     IN OUT cg$row_type,
                                cg$ind     IN OUT cg$ind_type,
                                cg$old_rec IN     cg$row_type )
IS
  called_from BOOLEAN := called_from_package;
BEGIN

  null;
END domain_cascade_upd;


--------------------------------------------------------------------------------
-- Name:        upd_denorm
--
-- Description: API procedure for simple denormalization
--
-- Parameters:  cg$rec  Record of row to be updated
--              cg$ind  Record of columns specifically set
--              do_upd  Whether we want the actual UPDATE to occur
--------------------------------------------------------------------------------
PROCEDURE upd_denorm2( cg$rec IN cg$row_type,
                       cg$ind IN cg$ind_type ) IS
BEGIN
  NULL;
END upd_denorm2;


--------------------------------------------------------------------------------
-- Name:        upd_oper_denorm
--
-- Description: API procedure for operation denormalization
--
-- Parameters:  cg$rec  Record of row to be updated
--              cg$ind  Record of columns specifically set
--              do_upd  Whether we want the actual UPDATE to occur
--------------------------------------------------------------------------------
PROCEDURE upd_oper_denorm2( cg$rec IN cg$row_type,
                            cg$old_rec IN cg$row_type,
                            cg$ind IN cg$ind_type,
                            operation IN VARCHAR2 DEFAULT 'UPD'
					           )
IS
BEGIN















NULL;
END upd_oper_denorm2;

--------------------------------------------------------------------------------
-- Name:        del
--
-- Description: API delete procedure
--
-- Parameters:  cg$pk  Primary key record of row to be deleted
--------------------------------------------------------------------------------
PROCEDURE del(cg$pk IN cg$pk_type,
              do_del IN BOOLEAN DEFAULT TRUE) IS
BEGIN
--  Application_logic Pre-Delete <<Start>>
--  Application_logic Pre-Delete << End >>

--  Delete the record

    called_from_package := TRUE;

    IF (do_del) THEN
        DECLARE
           cg$rec cg$row_type;
           cg$old_rec cg$row_type;
           cg$ind cg$ind_type;
        BEGIN
           cg$rec.COD_ENTE := cg$pk.COD_ENTE;
           cg$rec.NRO_REPORTE := cg$pk.NRO_REPORTE;
           cg$rec.SECUENCIA := cg$pk.SECUENCIA;
           slct(cg$rec);

           validate_foreign_keys_del(cg$rec);
           validate_domain_cascade_delete(cg$rec);

           IF cg$pk.the_rowid is null THEN
              DELETE OS_REPORTES
              WHERE                    COD_ENTE = cg$pk.COD_ENTE
              AND          NRO_REPORTE = cg$pk.NRO_REPORTE
              AND          SECUENCIA = cg$pk.SECUENCIA;
           ELSE
              DELETE OS_REPORTES
              WHERE  rowid = cg$pk.the_rowid;
           END IF;

           upd_oper_denorm2(cg$rec, cg$old_rec, cg$ind, 'DEL');
           cascade_delete(cg$rec);
           domain_cascade_delete(cg$rec);
        END;
    END IF;

    called_from_package := FALSE;


--  Application_logic Post-Delete <<Start>>
--  Application_logic Post-Delete << End >>

EXCEPTION
    WHEN cg$errors.cg$error THEN
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN cg$errors.delete_restrict THEN
        err_msg(SQLERRM, cg$errors.ERR_DELETE_RESTRICT, 'cg$OS_REPORTES.del.delete_restrict');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN no_data_found THEN
        cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_DEL, cg$errors.ROW_DEL),
                       'E',
                       'ORA',
                       SQLCODE,
                       'cg$OS_REPORTES.del.no_data_found');
        called_from_package := FALSE;
        cg$errors.raise_failure;
    WHEN OTHERS THEN
        cg$errors.push(SQLERRM,
                       'E',
                       'ORA',
                       SQLCODE,
                       'cg$OS_REPORTES.del.others');
        called_from_package := FALSE;
        cg$errors.raise_failure;
END del;


--------------------------------------------------------------------------------
-- Name:        lck
--
-- Description: API lock procedure
--
-- Parameters:  cg$old_rec  Calling apps view of record of row to be locked
--              cg$old_ind  Record of columns to raise error if modified
--              nowait_flag TRUE lock with NOWAIT, FALSE don't fail if busy
--------------------------------------------------------------------------------
PROCEDURE lck(cg$old_rec IN cg$row_type,
              cg$old_ind IN cg$ind_type,
              nowait_flag IN BOOLEAN DEFAULT TRUE) IS
cg$tmp_rec cg$row_type;
any_modified BOOLEAN := FALSE;

BEGIN
--  Application_logic Pre-Lock <<Start>>
--  Application_logic Pre-Lock << End >>

--  Do the row lock

    BEGIN
        IF (nowait_flag) THEN
            IF cg$old_rec.the_rowid is null THEN
               SELECT       COD_ENTE
               ,            NRO_REPORTE
               ,            SECUENCIA
               ,            DES_BREVE
               ,            TIP_REPORTE
               ,            TIP_ACTIVIDAD
               ,            FEC_INGRESO
               ,            EST_REPORTE
               ,            FEC_ENVIO
               ,            DES_DETALLADA
               ,            TIPOLOGIA
               ,            USU_INSERCION
               ,            FEC_INSERCION
               ,            USU_MODIFICACION
               ,            FEC_MODIFICACION
               INTO         cg$tmp_rec.COD_ENTE
               ,            cg$tmp_rec.NRO_REPORTE
               ,            cg$tmp_rec.SECUENCIA
               ,            cg$tmp_rec.DES_BREVE
               ,            cg$tmp_rec.TIP_REPORTE
               ,            cg$tmp_rec.TIP_ACTIVIDAD
               ,            cg$tmp_rec.FEC_INGRESO
               ,            cg$tmp_rec.EST_REPORTE
               ,            cg$tmp_rec.FEC_ENVIO
               ,            cg$tmp_rec.DES_DETALLADA
               ,            cg$tmp_rec.TIPOLOGIA
               ,            cg$tmp_rec.USU_INSERCION
               ,            cg$tmp_rec.FEC_INSERCION
               ,            cg$tmp_rec.USU_MODIFICACION
               ,            cg$tmp_rec.FEC_MODIFICACION
               FROM      OS_REPORTES
               WHERE              COD_ENTE = cg$old_rec.COD_ENTE
               AND          NRO_REPORTE = cg$old_rec.NRO_REPORTE
               AND          SECUENCIA = cg$old_rec.SECUENCIA
               FOR UPDATE NOWAIT;
            ELSE
               SELECT       COD_ENTE
               ,            NRO_REPORTE
               ,            SECUENCIA
               ,            DES_BREVE
               ,            TIP_REPORTE
               ,            TIP_ACTIVIDAD
               ,            FEC_INGRESO
               ,            EST_REPORTE
               ,            FEC_ENVIO
               ,            DES_DETALLADA
               ,            TIPOLOGIA
               ,            USU_INSERCION
               ,            FEC_INSERCION
               ,            USU_MODIFICACION
               ,            FEC_MODIFICACION
               INTO         cg$tmp_rec.COD_ENTE
               ,            cg$tmp_rec.NRO_REPORTE
               ,            cg$tmp_rec.SECUENCIA
               ,            cg$tmp_rec.DES_BREVE
               ,            cg$tmp_rec.TIP_REPORTE
               ,            cg$tmp_rec.TIP_ACTIVIDAD
               ,            cg$tmp_rec.FEC_INGRESO
               ,            cg$tmp_rec.EST_REPORTE
               ,            cg$tmp_rec.FEC_ENVIO
               ,            cg$tmp_rec.DES_DETALLADA
               ,            cg$tmp_rec.TIPOLOGIA
               ,            cg$tmp_rec.USU_INSERCION
               ,            cg$tmp_rec.FEC_INSERCION
               ,            cg$tmp_rec.USU_MODIFICACION
               ,            cg$tmp_rec.FEC_MODIFICACION
               FROM      OS_REPORTES
               WHERE rowid = cg$old_rec.the_rowid
               FOR UPDATE NOWAIT;
            END IF;
        ELSE
            IF cg$old_rec.the_rowid is null THEN
               SELECT       COD_ENTE
               ,            NRO_REPORTE
               ,            SECUENCIA
               ,            DES_BREVE
               ,            TIP_REPORTE
               ,            TIP_ACTIVIDAD
               ,            FEC_INGRESO
               ,            EST_REPORTE
               ,            FEC_ENVIO
               ,            DES_DETALLADA
               ,            TIPOLOGIA
               ,            USU_INSERCION
               ,            FEC_INSERCION
               ,            USU_MODIFICACION
               ,            FEC_MODIFICACION
               INTO         cg$tmp_rec.COD_ENTE
               ,            cg$tmp_rec.NRO_REPORTE
               ,            cg$tmp_rec.SECUENCIA
               ,            cg$tmp_rec.DES_BREVE
               ,            cg$tmp_rec.TIP_REPORTE
               ,            cg$tmp_rec.TIP_ACTIVIDAD
               ,            cg$tmp_rec.FEC_INGRESO
               ,            cg$tmp_rec.EST_REPORTE
               ,            cg$tmp_rec.FEC_ENVIO
               ,            cg$tmp_rec.DES_DETALLADA
               ,            cg$tmp_rec.TIPOLOGIA
               ,            cg$tmp_rec.USU_INSERCION
               ,            cg$tmp_rec.FEC_INSERCION
               ,            cg$tmp_rec.USU_MODIFICACION
               ,            cg$tmp_rec.FEC_MODIFICACION
               FROM      OS_REPORTES
               WHERE              COD_ENTE = cg$old_rec.COD_ENTE
               AND          NRO_REPORTE = cg$old_rec.NRO_REPORTE
               AND          SECUENCIA = cg$old_rec.SECUENCIA
               FOR UPDATE;
            ELSE
               SELECT       COD_ENTE
               ,            NRO_REPORTE
               ,            SECUENCIA
               ,            DES_BREVE
               ,            TIP_REPORTE
               ,            TIP_ACTIVIDAD
               ,            FEC_INGRESO
               ,            EST_REPORTE
               ,            FEC_ENVIO
               ,            DES_DETALLADA
               ,            TIPOLOGIA
               ,            USU_INSERCION
               ,            FEC_INSERCION
               ,            USU_MODIFICACION
               ,            FEC_MODIFICACION
               INTO         cg$tmp_rec.COD_ENTE
               ,            cg$tmp_rec.NRO_REPORTE
               ,            cg$tmp_rec.SECUENCIA
               ,            cg$tmp_rec.DES_BREVE
               ,            cg$tmp_rec.TIP_REPORTE
               ,            cg$tmp_rec.TIP_ACTIVIDAD
               ,            cg$tmp_rec.FEC_INGRESO
               ,            cg$tmp_rec.EST_REPORTE
               ,            cg$tmp_rec.FEC_ENVIO
               ,            cg$tmp_rec.DES_DETALLADA
               ,            cg$tmp_rec.TIPOLOGIA
               ,            cg$tmp_rec.USU_INSERCION
               ,            cg$tmp_rec.FEC_INSERCION
               ,            cg$tmp_rec.USU_MODIFICACION
               ,            cg$tmp_rec.FEC_MODIFICACION
               FROM      OS_REPORTES
               WHERE rowid = cg$old_rec.the_rowid
               FOR UPDATE;
            END IF;
        END IF;

    EXCEPTION
        WHEN cg$errors.cg$error THEN
            cg$errors.raise_failure;
        WHEN cg$errors.resource_busy THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_LCK, cg$errors.ROW_LCK),
                           'E',
                           'ORA',
                           SQLCODE,
                           'cg$OS_REPORTES.lck.resource_busy');
            cg$errors.raise_failure;
        WHEN no_data_found THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_DEL, cg$errors.ROW_DEL),
                           'E',
                           'ORA',
                           SQLCODE,
                           'cg$OS_REPORTES.lck.no_data_found');
            cg$errors.raise_failure;
        WHEN OTHERS THEN
            cg$errors.push(SQLERRM,
                           'E',
                           'ORA',
                           SQLCODE,
                           'cg$OS_REPORTES.lck.others');
            cg$errors.raise_failure;
    END;

-- Optional Columns

    IF (cg$old_ind.DES_BREVE) THEN
        IF (cg$tmp_rec.DES_BREVE IS NOT NULL
        AND cg$old_rec.DES_BREVE IS NOT NULL) THEN
            IF (cg$tmp_rec.DES_BREVE != cg$old_rec.DES_BREVE) THEN
                cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P40DES_BREVE
                    ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
                any_modified := TRUE;
            END IF;
        ELSIF (cg$tmp_rec.DES_BREVE IS NOT NULL
        OR cg$old_rec.DES_BREVE IS NOT NULL) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P40DES_BREVE
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.FEC_ENVIO) THEN
        IF (cg$tmp_rec.FEC_ENVIO IS NOT NULL
        AND cg$old_rec.FEC_ENVIO IS NOT NULL) THEN
            IF (cg$tmp_rec.FEC_ENVIO != cg$old_rec.FEC_ENVIO) THEN
                cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P90FEC_ENVIO
                    ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
                any_modified := TRUE;
            END IF;
        ELSIF (cg$tmp_rec.FEC_ENVIO IS NOT NULL
        OR cg$old_rec.FEC_ENVIO IS NOT NULL) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P90FEC_ENVIO
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.DES_DETALLADA) THEN
        IF (cg$tmp_rec.DES_DETALLADA IS NOT NULL
        AND cg$old_rec.DES_DETALLADA IS NOT NULL) THEN
            IF (cg$tmp_rec.DES_DETALLADA != cg$old_rec.DES_DETALLADA) THEN
                cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P100DES_DETALLADA
                    ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
                any_modified := TRUE;
            END IF;
        ELSIF (cg$tmp_rec.DES_DETALLADA IS NOT NULL
        OR cg$old_rec.DES_DETALLADA IS NOT NULL) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P100DES_DETALLADA
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.TIPOLOGIA) THEN
        IF (cg$tmp_rec.TIPOLOGIA IS NOT NULL
        AND cg$old_rec.TIPOLOGIA IS NOT NULL) THEN
            IF (cg$tmp_rec.TIPOLOGIA != cg$old_rec.TIPOLOGIA) THEN
                cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P110TIPOLOGIA
                    ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
                any_modified := TRUE;
            END IF;
        ELSIF (cg$tmp_rec.TIPOLOGIA IS NOT NULL
        OR cg$old_rec.TIPOLOGIA IS NOT NULL) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P110TIPOLOGIA
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;

-- Mandatory Columns

    IF (cg$old_ind.COD_ENTE) THEN
        IF (cg$tmp_rec.COD_ENTE != cg$old_rec.COD_ENTE) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P10COD_ENTE
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.NRO_REPORTE) THEN
        IF (cg$tmp_rec.NRO_REPORTE != cg$old_rec.NRO_REPORTE) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P20NRO_REPORTE
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.SECUENCIA) THEN
        IF (cg$tmp_rec.SECUENCIA != cg$old_rec.SECUENCIA) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P30SECUENCIA
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.TIP_REPORTE) THEN
        IF (cg$tmp_rec.TIP_REPORTE != cg$old_rec.TIP_REPORTE) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P50TIP_REPORTE
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.TIP_ACTIVIDAD) THEN
        IF (cg$tmp_rec.TIP_ACTIVIDAD != cg$old_rec.TIP_ACTIVIDAD) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P60TIP_ACTIVIDAD
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.FEC_INGRESO) THEN
        IF (cg$tmp_rec.FEC_INGRESO != cg$old_rec.FEC_INGRESO) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P70FEC_INGRESO
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.EST_REPORTE) THEN
        IF (cg$tmp_rec.EST_REPORTE != cg$old_rec.EST_REPORTE) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P80EST_REPORTE
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.USU_INSERCION) THEN
        IF (cg$tmp_rec.USU_INSERCION != cg$old_rec.USU_INSERCION) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P120USU_INSERCION
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.FEC_INSERCION) THEN
        IF (cg$tmp_rec.FEC_INSERCION != cg$old_rec.FEC_INSERCION) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P130FEC_INSERCION
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.USU_MODIFICACION) THEN
        IF (cg$tmp_rec.USU_MODIFICACION != cg$old_rec.USU_MODIFICACION) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P140USU_MODIFICACION
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;
    IF (cg$old_ind.FEC_MODIFICACION) THEN
        IF (cg$tmp_rec.FEC_MODIFICACION != cg$old_rec.FEC_MODIFICACION) THEN
            cg$errors.push(cg$errors.MsgGetText(cg$errors.API_ROW_MOD, cg$errors.ROW_MOD, P150FEC_MODIFICACION
                ),'E', 'API', CG$ERRORS.API_MODIFIED, 'cg$OS_REPORTES.lck');
            any_modified := TRUE;
        END IF;
    END IF;

    IF (any_modified) THEN
        cg$errors.raise_failure;
    END IF;

--  Application_logic Post-Lock <<Start>>
--  Application_logic Post-Lock << End >>

END lck;


BEGIN
      cg$ind_true.COD_ENTE := TRUE;
      cg$ind_true.NRO_REPORTE := TRUE;
      cg$ind_true.SECUENCIA := TRUE;
      cg$ind_true.DES_BREVE := TRUE;
      cg$ind_true.TIP_REPORTE := TRUE;
      cg$ind_true.TIP_ACTIVIDAD := TRUE;
      cg$ind_true.FEC_INGRESO := TRUE;
      cg$ind_true.EST_REPORTE := TRUE;
      cg$ind_true.FEC_ENVIO := TRUE;
      cg$ind_true.DES_DETALLADA := TRUE;
      cg$ind_true.TIPOLOGIA := TRUE;
      cg$ind_true.USU_INSERCION := TRUE;
      cg$ind_true.FEC_INSERCION := TRUE;
      cg$ind_true.USU_MODIFICACION := TRUE;
      cg$ind_true.FEC_MODIFICACION := TRUE;


END cg$OS_REPORTES;
/

