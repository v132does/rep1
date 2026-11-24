create or replace procedure it.prc_ins_aut_rch_clearing(rp_rch_aut in cc_che_rec_automaticos%rowtype) is
v_nro_lote      cc_che_rec_automaticos.nro_lote%type := 0;
v_can_reg       number := 0; 
v_ya_existe     number := 0;                          
                              
begin
   --si el rechazo automatico esta activo, se obtiene el max. nro de lote y se le suma 1
   if nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' then
      v_nro_lote := 0;
      if rp_rch_aut.nro_lote is null then
         begin
            select nvl(max(a.nro_lote),0)
              into v_nro_lote
              from cc_che_rec_automaticos a;         
         exception
            when others then
               v_nro_lote := 0;
         end;
         
         v_nro_lote := nvl(v_nro_lote,0) + 1;
      else
         v_nro_lote := rp_rch_aut.nro_lote;   
      end if;                 
   end if; 
   
   --se verifica si ya existe el mismo registro
   v_can_reg := 0;
   begin
      select nvl(count(*),0)
        into v_can_reg
        from cc_che_rec_automaticos a
       where a.nro_cuenta = rp_rch_aut.nro_cuenta
         and a.nro_cheque = rp_rch_aut.nro_cheque
         and a.cod_bco_receptor = rp_rch_aut.cod_bco_receptor
         and a.cod_moneda = rp_rch_aut.cod_moneda
         and a.fec_proceso = rp_rch_aut.fec_proceso
         and upper(a.cod_usuario) = upper(rp_rch_aut.cod_usuario)
         and nvl(a.procesado,'N') = 'N'; 
   exception
      when no_data_found then
         v_can_reg := 0;
      when others then
         raise_application_error(-20001,'Error al verificar la existencia del registro.'||sqlerrm);
   end;     
   
   --
   begin
      select nvl(count(*),0)
        into v_ya_existe
        from cc_che_rec_automaticos a
       where a.nro_cuenta = rp_rch_aut.nro_cuenta
         and a.nro_cheque = rp_rch_aut.nro_cheque
         and a.cod_bco_receptor = rp_rch_aut.cod_bco_receptor
         and a.cod_moneda = rp_rch_aut.cod_moneda
         and a.fec_proceso = rp_rch_aut.fec_proceso; 
   exception
      when no_data_found then
         v_ya_existe := 0;
      when others then
         raise_application_error(-20002,'Error al verificar la existencia del registro. '||sqlerrm);
   end;     
    
   if nvl(v_ya_existe,0) > 0 then
      if nvl(v_can_reg,0) > 0 then
         delete from cc_che_rec_automaticos a
          where a.nro_cuenta = rp_rch_aut.nro_cuenta
            and a.nro_cheque = rp_rch_aut.nro_cheque
            and a.cod_bco_receptor = rp_rch_aut.cod_bco_receptor
            and a.cod_moneda = rp_rch_aut.cod_moneda
            and a.fec_proceso = rp_rch_aut.fec_proceso
            and upper(a.cod_usuario) = upper(rp_rch_aut.cod_usuario)
            and nvl(a.procesado,'N') = 'N';
         
         if sql%rowcount = 0 then
           raise_application_error(-20003, 'No se encontró el registro para eliminar.');
         end if; 
      end if;        
   end if;
   
   begin
      insert into cc_che_rec_automaticos(nro_cheque, fec_proceso, nro_cuenta, monto, cod_bco_receptor, 
      cod_ofi_camara, cod_oficina, cod_cau_devolucion, des_cau_devolucion, cod_usuario, 
      tip_importe, cod_moneda, procesado, des_error, nro_lote, 
      origen)
      values (rp_rch_aut.nro_cheque,rp_rch_aut.fec_proceso,rp_rch_aut.nro_cuenta,rp_rch_aut.monto,rp_rch_aut.cod_bco_receptor,
      rp_rch_aut.cod_ofi_camara, rp_rch_aut.cod_oficina, rp_rch_aut.cod_cau_devolucion, rp_rch_aut.des_cau_devolucion, rp_rch_aut.cod_usuario,
      rp_rch_aut.tip_importe, rp_rch_aut.cod_moneda, rp_rch_aut.procesado, rp_rch_aut.des_error, v_nro_lote,
      rp_rch_aut.origen);
   exception
      when others then
        raise_application_error(-20004, 'Error al registrar los datos. '||sqlerrm); 
   end; 
exception
   when others then
      raise_application_error(-20005, 'Error al registrar los cheques rechazados aut. '||sqlerrm); 
end;
/
