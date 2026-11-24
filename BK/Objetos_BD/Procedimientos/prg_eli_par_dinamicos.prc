CREATE OR REPLACE PROCEDURE IT.PRG_ELI_PAR_DINAMICOS IS
  --Procedimiento p/ eliminar automaticamente par. din. cargados en la referencia--
  --Creado para eliminacion de parametros utilizado para exclusion de Limites con errores en el Ciere DYDMR-5047 / rpavon 23.09.2016--
BEGIN
  delete from ge_par_dinamicos a
   where exists (select 1
                   from ba_cod_referencias x
                  where x.dominio = 'PAR_DIN_ELIMINAR'
                    and x.val_minimo = a.parametro);
exception 
  when others then 
       raise_application_error(-20000,'Error en PRG_ELI_PAR_DINAMICOS '||sqlerrm);
END;
/

