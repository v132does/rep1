CREATE OR REPLACE TRIGGER IT.TB_GE_SPI_INFORMES
 BEFORE UPDATE OF SITUACION, ESTADO
 ON GE_SPI_INFORMES
 FOR EACH ROW
DECLARE
 v_cant      number;
BEGIN
   if updating then

     if (:new.situacion <> :old.situacion) and :new.situacion='P'  then
       select SUM(t.cantidad)
       into v_cant from ge_spi_log_controles t

       where t.nro_referencia= :new.nro_referencia and t.nro_ref_externa= :new.nro_ref_externa;

       if v_cant >=3 then
          :new.situacion     := 'N';
          :new.estado        := 'U';
       end if;
    end if;
    if :new.cod_msj_mx='pacs.002' and :new.msj_mx is not null then--enviado, con respecto a pacs 008 recibo
        if (:new.situacion <> :old.situacion) and :new.situacion='V'  then
          if (:new.estado <> :old.estado) and :new.estado='W'  then
            if  :new.inf_suplementaria= 'AUTH'  then
              update ge_snp_transferencias t
              set t.estado='A'
              where t.nro_ref_externa=:new.nro_ref_msj_original;
            end if;
            if  :new.inf_suplementaria= 'NAUT'  then
              update ge_snp_transferencias t
              set t.estado='R'
              where t.nro_ref_externa=:new.nro_ref_msj_original;
            end if;
          end if;
        end if;
   end if;
   end if;
EXCEPTION
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'Error en TB_GE_SPI_INFORMES: '|| sqlerrm);
     end if;
END;
/

