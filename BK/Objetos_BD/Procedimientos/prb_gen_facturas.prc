CREATE OR REPLACE PROCEDURE IT.PRB_GEN_FACTURAS
  is
/* OMM - Mar/2017. Para generar facturas desde el temporal por usuario inserción,
   se utiliza para completar la importación de facturas manuales de RRHH */

 v_cod_usuario   varchar2(200) := nvl(fug_obt_pardinamico('SAU_USU_FACTURA'),user);
begin

    pab_iva.PR_GEN_FACTURA(null, null, null, v_cod_usuario) ;

exception
when others then
    raise_application_error(-20005, 'En PRB_GEN_FACTURAS-'||v_cod_usuario||'-'||sqlerrm);
end ;
/

