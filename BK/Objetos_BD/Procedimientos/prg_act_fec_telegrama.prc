CREATE OR REPLACE PROCEDURE IT.PRG_ACT_FEC_TELEGRAMA
 (P_COD_TELEGRAMA IN GE_TELEGRAMAS.COD_TELEGRAMA%TYPE
 ,P_FECHA IN DATE,
 P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 IS
begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo:=3;
  update ge_telegramas
     set fec_impresion = p_fecha,
     estado = 'I',
     cod_usu_impresion = p_cod_usuario
   where cod_telegrama = nvl(p_cod_telegrama,cod_telegrama)
     and fec_entrega is null;
end;
/

