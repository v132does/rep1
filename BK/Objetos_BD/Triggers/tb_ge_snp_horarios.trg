CREATE OR REPLACE TRIGGER IT.TB_GE_SNP_HORARIOS
  BEFORE UPDATE of estado
     ON GE_SNP_HORARIOS
    FOR EACH ROW       WHEN (new.estado = 'A') DECLARE
  /*
  || Archivo creado por el Oscar Balmaceda
  || El 07/08/2013 a las 10:29 Hs.
  */
  v_cod_periodo_cre_informes NUMBER(2) := fug_obt_pardinamico('SNP_COD_PER_CIERRE');
BEGIN
  if updating and :new.cod_periodo = v_cod_periodo_cre_informes then
    :new.estado := 'C';
  end if;
EXCEPTION
  when others then
    it_mail.mail(fug_obt_dir_correo, fug_obt_pardinamico('SNP_ERR_DIR_CORREO'), 'Error al tratar de realizar el cierre de Periodo - SIPAP',
                                                         'Error al disparar el trigger TB_GE_SNP_HORARIOS '||sqlerrm);
END;
/

