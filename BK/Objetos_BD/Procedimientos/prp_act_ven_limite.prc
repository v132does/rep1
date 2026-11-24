CREATE OR REPLACE PROCEDURE IT.PRP_ACT_VEN_LIMITE
IS
v_fec_actual date;
v_cta_cambios lc_cta_cambios.nro_cuenta%type;

cursor limites is
    select rowid fila, nro_linea
      from pr_lineas
     where trunc(fec_vencimiento) <  v_fec_actual
      and estado in('A', 'B');
/*dydmr-1333 10/12/2014 FM*/
--Limites Pendientes sin Aprobacion Vencidos--   
cursor c_lim_ven_noaprob is
    select rowid fila, nro_linea
      from pr_lineas
     where trunc(fec_vencimiento) <  v_fec_actual
      and estado = 'P';     
      
      
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
  for lim in limites loop
    update pr_lineas set estado = 'V'
     where rowid = lim.fila;
    prp_ins_his_limite(lim.nro_linea);
    prp_eli_limite(lim.nro_linea);
    --WA: 02/04/2014 Ajuste para pasar a Vencidas Ctas de Cambios,
    --si vence la linea global.
    v_cta_cambios:=null;
    begin
      select a.nro_cuenta
       into v_cta_cambios
        from lc_cta_cambios a
         where a.nro_linea= lim.nro_linea
          and a.estado not in ('V','C')
           and rownum=1
           order by a.fec_insercion desc;
    exception
      when no_data_found then
        v_cta_cambios:=null;
      when others then
        v_cta_cambios:=null;
    end;
    --Si existe, hacemos update
    if   nvl(v_cta_cambios,'XX') <> 'XX' THEN
       update lc_cta_cambios a
        set a.estado='V' -- Se pasa a Vencida
         where a.nro_cuenta=v_cta_cambios;
    end if;

  end loop;
  
  for lim in c_lim_ven_noaprob loop
      /*dydmr-1333 10/12/14 FM
      Lineas de Credito Pendientes y vencidas*/
       Delete pr_lin_aplicaciones
        where nro_linea = lim.nro_linea;
       Delete pr_lin_tip_gar_mad
        where nro_linea = lim.nro_linea;
       Delete pr_lin_tip_garantias
        where nro_linea = lim.nro_linea;
       Delete pr_lineas
        where nro_linea = lim.nro_linea;
       DELETE pr_lin_pre_aprobados
        WHERE nro_lin_pre_aprobado = lim.nro_linea; 
  end loop;
  
end;
/

