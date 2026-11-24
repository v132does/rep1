CREATE OR REPLACE TRIGGER IT.TA_GE_COB_SER_CUOTAS
  AFTER insert or DELETE OR UPDATE
     ON GE_COB_SER_CUOTAS
    FOR EACH ROW

DECLARE
  v_cuota number :=0;
BEGIN
  if updating then
  	if :old.estado <> 'P' and :new.estado = 'P' and
       :old.fec_cobro is null and :new.fec_cobro is not null then
         --es un cobro
         v_cuota := 1;
    end if;
    if :new.estado <> 'P' and :old.estado = 'P' and
       :new.fec_cobro is null and :old.fec_cobro is not null then 
         --es una reversion
         v_cuota := -1;
    end if;
    if v_cuota <> 0 then
       update ge_cob_ser_cuentas
          set can_cuo_pagadas = nvl(can_cuo_pagadas,0) + v_cuota
        where cod_servicio = :new.cod_servicio
          and nro_cuenta = :new.nro_cuenta;
    end if;  
  end if;
END;
/

