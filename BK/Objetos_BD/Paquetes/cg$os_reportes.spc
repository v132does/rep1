CREATE OR REPLACE PACKAGE IT.cg$OS_REPORTES IS


called_from_package BOOLEAN := FALSE;

--  Repository User-Defined Error Messages
PK_OS_REPORTES CONSTANT VARCHAR2(240) := 'Reporte ya existe.';
CC_OREPO_SEC_TIP_REPORTE CONSTANT VARCHAR(240) := 'Tipo de Reporte Inicial solo puede registrarse con la primera Sec.';
FK_OREPO_COD_ENTE CONSTANT VARCHAR2(240) := 'El Ente no existe, verifique..';

--  Column default prompts. Format PSEQNO_COL
P10COD_ENTE CONSTANT VARCHAR2(240) := 'Ente';
P20NRO_REPORTE CONSTANT VARCHAR2(240) := 'Nro Reporte';
P30SECUENCIA CONSTANT VARCHAR2(240) := 'Secuencia';
P40DES_BREVE CONSTANT VARCHAR2(240) := 'Des Breve';
P50TIP_REPORTE CONSTANT VARCHAR2(240) := 'Tip Reporte';
P60TIP_ACTIVIDAD CONSTANT VARCHAR2(240) := 'Tip Actividad';
P70FEC_INGRESO CONSTANT VARCHAR2(240) := 'Fec Ingreso';
P80EST_REPORTE CONSTANT VARCHAR2(240) := 'Est Reporte';
P90FEC_ENVIO CONSTANT VARCHAR2(240) := 'Fec Envio';
P100DES_DETALLADA CONSTANT VARCHAR2(240) := 'Des Detallada';
P110TIPOLOGIA CONSTANT VARCHAR2(240) := 'Tipologia';
P120USU_INSERCION CONSTANT VARCHAR2(240) := 'Usu Insercion';
P130FEC_INSERCION CONSTANT VARCHAR2(240) := 'Fec Insercion';
P140USU_MODIFICACION CONSTANT VARCHAR2(240) := 'Usu Modificacion';
P150FEC_MODIFICACION CONSTANT VARCHAR2(240) := 'Fec Modificacion';

cg$row OS_REPORTES%ROWTYPE;

--  OS_REPORTES row type variable
TYPE cg$row_type IS RECORD
(COD_ENTE cg$row.COD_ENTE%TYPE
,NRO_REPORTE cg$row.NRO_REPORTE%TYPE
,SECUENCIA cg$row.SECUENCIA%TYPE
,DES_BREVE cg$row.DES_BREVE%TYPE
,TIP_REPORTE cg$row.TIP_REPORTE%TYPE
,TIP_ACTIVIDAD cg$row.TIP_ACTIVIDAD%TYPE
,FEC_INGRESO cg$row.FEC_INGRESO%TYPE
,EST_REPORTE cg$row.EST_REPORTE%TYPE
,FEC_ENVIO cg$row.FEC_ENVIO%TYPE
,DES_DETALLADA cg$row.DES_DETALLADA%TYPE
,TIPOLOGIA cg$row.TIPOLOGIA%TYPE
,USU_INSERCION cg$row.USU_INSERCION%TYPE
,FEC_INSERCION cg$row.FEC_INSERCION%TYPE
,USU_MODIFICACION cg$row.USU_MODIFICACION%TYPE
,FEC_MODIFICACION cg$row.FEC_MODIFICACION%TYPE
,the_rowid ROWID)
;

--  OS_REPORTES indicator type variable
TYPE cg$ind_type IS RECORD
(COD_ENTE BOOLEAN DEFAULT FALSE
,NRO_REPORTE BOOLEAN DEFAULT FALSE
,SECUENCIA BOOLEAN DEFAULT FALSE
,DES_BREVE BOOLEAN DEFAULT FALSE
,TIP_REPORTE BOOLEAN DEFAULT FALSE
,TIP_ACTIVIDAD BOOLEAN DEFAULT FALSE
,FEC_INGRESO BOOLEAN DEFAULT FALSE
,EST_REPORTE BOOLEAN DEFAULT FALSE
,FEC_ENVIO BOOLEAN DEFAULT FALSE
,DES_DETALLADA BOOLEAN DEFAULT FALSE
,TIPOLOGIA BOOLEAN DEFAULT FALSE
,USU_INSERCION BOOLEAN DEFAULT FALSE
,FEC_INSERCION BOOLEAN DEFAULT FALSE
,USU_MODIFICACION BOOLEAN DEFAULT FALSE
,FEC_MODIFICACION BOOLEAN DEFAULT FALSE);

cg$ind_true cg$ind_type;

--  OS_REPORTES primary key type variable
TYPE cg$pk_type IS RECORD
(COD_ENTE cg$row.COD_ENTE%TYPE
,NRO_REPORTE cg$row.NRO_REPORTE%TYPE
,SECUENCIA cg$row.SECUENCIA%TYPE
,the_rowid ROWID)
;

--  PL/SQL Table Type variable for triggers
TYPE cg$table_type IS TABLE OF OS_REPORTES%ROWTYPE
     INDEX BY BINARY_INTEGER;
cg$table cg$table_type;

TYPE cg$tableind_type IS TABLE OF cg$ind_type
     INDEX BY BINARY_INTEGER;
cg$tableind cg$tableind_type;
idx BINARY_INTEGER := 1;

PROCEDURE   ins(cg$rec IN OUT cg$row_type,
                cg$ind IN OUT cg$ind_type,
                do_ins IN BOOLEAN DEFAULT TRUE
               );
PROCEDURE   upd(cg$rec             IN OUT cg$row_type,
                cg$ind             IN OUT cg$ind_type,
                do_upd             IN BOOLEAN     DEFAULT TRUE,
                cg$pk              IN cg$row_type DEFAULT NULL
               );
PROCEDURE   del(cg$pk  IN cg$pk_type,
                do_del IN BOOLEAN DEFAULT TRUE
               );
PROCEDURE   lck(cg$old_rec  IN cg$row_type,
                cg$old_ind  IN cg$ind_type,
                nowait_flag IN BOOLEAN DEFAULT TRUE
               );
PROCEDURE   slct(cg$sel_rec IN OUT cg$row_type);

PROCEDURE   validate_arc(cg$rec IN OUT cg$row_type);

PROCEDURE   validate_domain(cg$rec IN OUT cg$row_type,
                            cg$ind IN cg$ind_type DEFAULT cg$ind_true);

PROCEDURE   validate_foreign_keys_ins(cg$rec IN cg$row_type);
PROCEDURE   validate_foreign_keys_upd(cg$rec IN cg$row_type,
                                      cg$old_rec IN cg$row_type,
                                      cg$ind IN cg$ind_type);
PROCEDURE   validate_foreign_keys_del(cg$rec IN cg$row_type);

PROCEDURE   validate_domain_cascade_delete(cg$old_rec IN cg$row_type);
PROCEDURE   validate_domain_cascade_update(cg$old_rec IN cg$row_type);

PROCEDURE   cascade_update(cg$new_rec IN OUT cg$row_type,
                           cg$old_rec IN cg$row_type );
PROCEDURE   domain_cascade_update(cg$new_rec IN OUT cg$row_type,
                                  cg$new_ind IN OUT cg$ind_type,
                                  cg$old_rec IN     cg$row_type);
PROCEDURE   domain_cascade_upd( cg$rec     IN OUT cg$row_type,
                                cg$ind     IN OUT cg$ind_type,
                                cg$old_rec IN     cg$row_type);

PROCEDURE   cascade_delete(cg$old_rec IN OUT cg$row_type);
PROCEDURE   domain_cascade_delete(cg$old_rec IN cg$row_type);

PROCEDURE   upd_denorm2( cg$rec IN cg$row_type,
                         cg$ind IN cg$ind_type );
PROCEDURE   upd_oper_denorm2( cg$rec IN cg$row_type,
                              cg$old_rec IN cg$row_type,
                              cg$ind IN cg$ind_type,
                              operation IN VARCHAR2 DEFAULT 'UPD' );
END cg$OS_REPORTES;
/

