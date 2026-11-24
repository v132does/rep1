CREATE OR REPLACE PACKAGE IT.PAE_FAT is

PROCEDURE PR_ACT_PER_FATCA (P_COD_PERSONA       IN BA_PERSONAS.COD_PERSONA%TYPE,
                            P_TIP_PERSONA       IN BA_PERSONAS.TIPO%TYPE,
                            P_COD_SEC_CONTABLE  IN GE_CLIENTES.COD_SEC_CONTABLE%TYPE DEFAULT NULL,
                            P_NOMINA            IN VARCHAR2 default 'N',
                            P_MENSAJE           OUT VARCHAR2,
                            P_ACT_CUENTA        IN VARCHAR2 default NULL);


PROCEDURE PR_OBT_IND_PER_FATCA (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_TIP_PERSONA IN BA_PERSONAS.TIPO%TYPE,
                                P_TIP_INDICIO IN OUT VARCHAR2,
                                P_OBSERVACION IN OUT VARCHAR2);

PROCEDURE PR_INS_HIS_PER_FATCA (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE);


PROCEDURE PR_ACT_FEC_CADUCIDAD;

FUNCTION FU_ES_PAI_FATCA(P_COD_PAIS BA_PAISES.COD_PAIS%TYPE) RETURN VARCHAR2;

PROCEDURE PR_ACT_BA_PER_FATCA (RP_PERFAT           IN BA_PER_FATCA%ROWTYPE,
                               P_ENV_MAIL          IN GE_EST_FATCA.IND_ENV_MAIL%TYPE DEFAULT NULL );
 
PROCEDURE PR_ACT_PAR_FATCA (p_cod_persona    ba_personas.cod_persona%type,
                            p_tip_persona    ba_personas.tipo%type,
                            p_parametro      ba_per_dat_adicionales.parametro%type, 
                            p_val_parametro  ba_per_dat_adicionales.val_parametro%type);
                            
PROCEDURE PR_VAL_GIIN;  

PROCEDURE PR_GEN_DAT_CLIENTE(P_FEC_SAL_AGREGADO GE_CALENDARIOS.FEC_ACTUAL%TYPE default null);

FUNCTION FU_OBT_DES_ESTADO(P_ESTADO GE_EST_FATCA.EST_FATCA%TYPE) RETURN VARCHAR2;   

PROCEDURE PR_ACT_EST_ALT_CUENTA(P_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE);                         

PROCEDURE PR_ACT_DAT_CLIENTE(P_FEC_SAL_AGREGADO GE_CALENDARIOS.FEC_ACTUAL%TYPE);

FUNCTION FU_OBT_SAL_AGREGADO(p_cod_persona ge_clientes.cod_persona%type, 
                             p_fec_saldo   ge_calendarios.fec_actual%type,
                             p_per_saldo   varchar2,
                             p_tip_cuenta   varchar2) return number;

FUNCTION FU_ES_PRO_SUSTANCIAL(p_cod_per_fisica ge_clientes.cod_persona%type, 
                              p_cod_per_juridica ge_clientes.cod_persona%type) return varchar2;
                              
FUNCTION FU_OBT_SAL_CANCELADO(p_cod_persona in ge_clientes.cod_persona%TYPE,
                            p_fec_saldo     in ge_calendarios.fec_actual%TYPE) RETURN NUMBER; 

FUNCTION FU_OBT_INT_PAGADO(p_cod_persona in ge_clientes.cod_persona%TYPE,
                           p_fec_desde   in ge_calendarios.fec_actual%TYPE,
                           p_fec_hasta   in ge_calendarios.fec_actual%TYPE) RETURN NUMBER; 
end PAE_FAT;
/

