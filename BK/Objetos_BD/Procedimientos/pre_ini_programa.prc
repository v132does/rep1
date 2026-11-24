CREATE OR REPLACE PROCEDURE IT.PRE_INI_PROGRAMA
 (P_COD_PROGRAMA IN BA_PROGRAMAS.COD_PROGRAMA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_SISTEMA IN BA_SISTEMAS.COD_SISTEMA%TYPE
 )
 IS
BEGIN
   pae_cnf.g_programa := p_cod_programa;
   pae_cnf.g_cod_modulo := p_cod_modulo;
   pae_cnf.g_cod_sistema := p_cod_sistema;
   pag_cta.PR_SET_EST_MOVIMIENTO('N'); -- seteo en 'N'-Normal la generacion de movimientos
END;
/

