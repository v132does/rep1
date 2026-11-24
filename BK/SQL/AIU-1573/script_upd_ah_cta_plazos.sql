/**  AIU-1573
   ACTUALIZACION MASIVA DE FECHA DE VENCIMIENTO DE AHORRO PROGRAMADO
**/
declare
 cursor cur_cta_plazos is
  select a.nro_cuenta, a.fec_vencimiento, a.usu_insercion
    from ah_cta_plazos a
   where a.estado not in ('T', 'C')
     and a.cod_modalidad = 38;

 v_fec_vencimiento ah_pro_cuotas.fec_vencimiento%type;
 v_new_fec_vencimiento ah_pro_cuotas.fec_vencimiento%type;
 
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
  /** recorremos las cuentas de ahorro programado **/
  for i in cur_cta_plazos loop

    /** 
       obtenemos la ultima fecha de vencimiento de la cuota por cuenta
    **/
    begin
      select max(s.fec_vencimiento)
        into v_fec_vencimiento
        from ah_pro_cuotas s
       where s.nro_cuenta = i.nro_cuenta
         and s.tipo = 'C';
    exception
      when others then
        raise_application_error(-20011,sqlerrm);
    end;
    
    /** 
       Calculamos la nueva fecha de vencimiento del ahorro programado usando la ultima fecha de vencimiento de la cuota,
       el criterio utilizado es tomar la ultima fecha vencimiento y sumar 1 mes, si la nueva fecha calculada no es dia habil
       entonces se asigna el siguiente dia habil
    **/
    v_new_fec_vencimiento := pag_cal.FU_OBT_FEC_HABIL(add_months(v_fec_vencimiento,1),1,61);
   
    /**
       Actualizamos el ahorro programado con la nueva fecha de vencimiento 
    **/
    update ah_cta_plazos a 
       set a.fec_vencimiento = v_new_fec_vencimiento
     where a.estado not in ('T', 'C')
       and a.cod_modalidad = 38
       and a.nro_cuenta = i.nro_cuenta;
       
  end loop;

  /** persistimos los datos en la base **/
  commit;
  /**************************************/

end;
