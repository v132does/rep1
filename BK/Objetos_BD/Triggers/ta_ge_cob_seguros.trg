CREATE OR REPLACE TRIGGER IT.TA_GE_COB_SEGUROS
  AFTER INSERT 
  ON GE_COB_SEGUROS
  FOR EACH ROW
declare
  -- local variables here
  v_nro_cuota ge_cuo_seguros.nro_cuota%type;
  v_cod_tip_seguro ge_cli_seguros.cod_tip_seguro%type;
  v_cod_sec_pol_seg  ge_pol_seguros.seccion%type;
  v_can_cuotas number;
  v_exi_exc_ren_seg varchar2(1);
  v_cod_ente ge_entes.cod_ente%type;
  v_max_cuo_seg number;
begin
  update ge_cuo_seguros a
     set a.estado = 'C',
         a.fec_ult_pago = :new.fecha
   where a.nro_seguro = :new.nro_seguro
     and a.nro_cuota  = :new.nro_cuota
     and a.fec_vencimiento = :new.fec_vencimiento;
  begin 
    select max(a.nro_cuota)
      into v_max_cuo_seg
      from ge_cuo_seguros a
     where a.nro_seguro = :new.nro_seguro;
  end;
  
  begin
    select max(a.nro_cuota)
      into v_nro_cuota
      from ge_cuo_seguros a
     where a.estado = 'C'
       and a.nro_seguro = :new.nro_seguro;
  end;
    
     
  begin
    select cod_tip_seguro, cod_ente
      into v_cod_tip_seguro, v_cod_ente
      from ge_cli_seguros
     where nro_seguro = :new.nro_seguro;
  exception
    when others then
      v_cod_ente := 0;
      v_cod_tip_seguro := 0;
  end;

  begin
    select val_minimo
      into v_cod_sec_pol_seg
      from ba_cod_referencias
     where dominio = 'REL_TIP_SEGUROS'
       and val_maximo = v_cod_tip_seguro;
  exception
    when others then
      v_cod_sec_pol_seg := '0';
  end;
   
  BEGIN
    select val_maximo
      into v_can_cuotas
      from ba_cod_referencias
     where dominio = 'CAN_CUO_SEGUROS'
       and val_minimo = v_cod_tip_seguro;
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        select val_maximo
          into v_can_cuotas
          from ba_cod_referencias
         where dominio = 'CAN_CUO_SEGUROS'
           and val_minimo = 0;
      EXCEPTION
        WHEN OTHERS THEN
          v_can_cuotas := 12;
      END;
  END;
  
  begin
    select distinct 'S'
      into v_exi_exc_ren_seg
      from ba_cod_referencias r
     where r.dominio = 'EXC_ENT_REN_SEG'
       and r.val_minimo = v_cod_sec_pol_seg||v_cod_ente
       and r.val_maximo = 'S';
  exception
    when others then
      v_exi_exc_ren_seg := 'N';
  end;
  
  if nvl(v_exi_exc_ren_seg, 'N') = 'S' then
     v_can_cuotas := 12;
  end if;
    
  if v_nro_cuota = nvl(v_can_cuotas,12) or v_nro_cuota = nvl(v_max_cuo_seg, 0) then
    update ge_cli_seguros a
       set a.can_cuo_pagadas = a.can_cuo_pagadas+1,
           a.estado = 'C'
     where a.nro_seguro = :new.nro_seguro;
  else 
    update ge_cli_seguros a
       set a.can_cuo_pagadas = a.can_cuo_pagadas+1
     where a.nro_seguro = :new.nro_seguro;
  end if;
end ta_ge_cob_seguros;
/

