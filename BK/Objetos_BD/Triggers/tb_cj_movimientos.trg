CREATE OR REPLACE TRIGGER IT.TB_CJ_MOVIMIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON it.CJ_MOVIMIENTOS
 FOR EACH ROW
declare

BEGIN
if :new.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
   if inserting then
      --actualizar retenciones tipo 1 q no se detallan
      if :new.tip_monto in ('O','T','S') and :new.monto > 0 and :new.tipo = 'D'
        and :new.cod_tra_padre not in (359,360,362,361) --Los Cobros de Préstamos se deben detallar
        then

        --WA:06/09/2013 se van a detallar los cheques de Cambios
        --if (:new.cod_tra_padre not in (246,245,241,242,372) and :new.tip_monto  in ('T','S','O')) then
        --JIRA DYDMR-1779/May-2015/se parametriza los codigos de transaccion padre en el grupo 804
        if ((FUP_EXI_GRU_TRANSAC(804,:new.cod_tra_padre,:new.cod_mod_padre, :new.cod_mad_padre) = 'N') and (:new.tip_monto  in ('T','S','O'))) then
         :new.tot_detallado := :new.monto;
         --si es operación normal
         if :new.estado = 'N' then
           --actualizar cj_controles
           update cj_controles
              set det_che_otr_bco = nvl(det_che_otr_bco,0) + nvl(:new.tot_detallado,0)
            where fecha      = :new.fecha
              and nro_caja   = :new.nro_caja
              and cod_moneda = :new.cod_moneda;
--
              if sql%notfound then
                 insert into cj_controles
                   (nro_caja, cod_moneda, fecha, estado,
                    mto_apertura, ini_che_otr_bco, cod_usu_actual,
                    tot_che_nue_bco, sal_actual, tot_debitos,
                    can_debitos, tot_che_otr_bco, sal_che_otr_bco, det_che_otr_bco)
                 select
                    :new.nro_caja, :new.cod_moneda, :new.fecha, 1,
                    0, 0, :new.cod_usuario,
                    0, 0, 0,
                    0, 0,
                    0, nvl(:new.tot_detallado,0) from dual;
              end if;
            end if;
--
          end if;
      end if;
   elsif updating then --verificar, xq la 200 ya actualiza datos de cj_movimientos y cj_controles
      if :new.estado = 'R' and :old.estado ='N' then --por reversión ojo! la reversión no inserta, actualiza
         if :old.tip_monto in ('O','T','S') and :old.tot_detallado > 0 and :old.tipo = 'D' then
            --actualizar cj_controles
            update cj_controles
               set det_che_otr_bco = nvl(det_che_otr_bco,0) - nvl(:old.tot_detallado,0)
             where fecha      = :old.fecha
               and nro_caja   = :old.nro_caja
               and cod_moneda = :old.cod_moneda;
         end if;
      end if;
   end if;
end if;
END;
/

