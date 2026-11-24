CREATE OR REPLACE TRIGGER IT.TA_GE_SPI_LOG_CONTROLES
  AFTER INSERT ON GE_SPI_LOG_CONTROLES
  FOR EACH ROW
DECLARE
 v_dir_correo          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_NOTIFICACIONES');
 no_procesa exception;
 v_msj_error varchar2(2000);
BEGIN
  if inserting  then
     if :new.cantidad= fug_obt_pardinamico( 'SPI_CANT_REINTENTO' ) then
         pas_spi.pr_gen_rev_tra_008(:new.nro_ref_externa);
          if pas_spi.fu_obt_cod_error <> 0 then
            v_msj_error:= pas_spi.fu_obt_msj_error;
          raise no_procesa;
          end if;
      end if;
  end if;
exception
  when no_procesa then
              begin
                    if v_dir_correo is not null then
                       it_mail.mail( fug_obt_dir_correo,
                                     v_dir_correo,
                                     'INCONVENIENTE EN REVERSION',
                                     'Hubo un error en la reversion de la operacion'
                                     || chr(10) ||'Nro. de referencia externa: '||:new.nro_ref_externa
                                     || chr(10) ||'Detalle Error: '||v_msj_error
                                    );
                    end if;
                exception
                  when others then
                     null;
                end;
  when others then
    null;
END;
/

