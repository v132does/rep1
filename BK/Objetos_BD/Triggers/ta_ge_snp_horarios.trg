CREATE OR REPLACE TRIGGER IT.TA_GE_SNP_HORARIOS
  AFTER UPDATE of estado
     ON GE_SNP_HORARIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Oscar Balmaceda
  || El 06/08/2013 a las 09:24 Hs.
  */
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_cod_periodo_cre_informes NUMBER(2) := fug_obt_pardinamico('SNP_COD_PER_CIERRE');
BEGIN
  if updating then
    if ((:new.cod_periodo = v_cod_periodo_cre_informes) ) then
      begin
        update GE_SNP_HORARIOS
           set estado = 'C'
         where cod_periodo != v_cod_periodo_cre_informes;
         commit;
      exception
        when no_data_found then
          it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SNP_ERR_DIR_CORREO'), 'Error al tratar de realizar el cierre de Periodo - SIPAP',
                                           	                   'No se han encontrado registros que actualizar');
        when others then
          it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SNP_ERR_DIR_CORREO'), 'Error al tratar de realizar el cierre de Periodo - SIPAP',
                                           	                   'Error al cerrar los periodos. '||sqlerrm);
      end;
    end if;
  end if;
EXCEPTION
  when others then
    it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SNP_ERR_DIR_CORREO'), 'Error al tratar de realizar el cierre de Periodo - SIPAP',
                                                         'Error al disparar el trigger TA_GE_SNP_HORARIOS '||sqlerrm);
END;
/

