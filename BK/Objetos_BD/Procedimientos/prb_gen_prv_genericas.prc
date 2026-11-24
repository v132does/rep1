CREATE OR REPLACE PROCEDURE IT.PRB_GEN_PRV_GENERICAS is

v_sal_contable  cb_sal_inventarios.sal_total%type;
v_sal_ponderado cb_sal_inventarios.sal_total%type;
v_mto_prevision cb_sal_inventarios.sal_total%type;
v_porcentaje    number;

--Obtengo los datos parametricos para generar el informe
cursor c_par_prv_generica is
select a.tip_riesgo,a.sec_riesgo,a.sec_inversion,a.cod_gru_rubro 
  from cb_par_prv_genericas a 
order by a.tip_riesgo,a.sec_riesgo,a.sec_inversion;

--Obtengo los datos de los valor correspondientes a los pasivos contingentes para calcular el ponderado.
cursor c_pas_contingente is
select a.tip_riesgo,a.sec_riesgo,a.sec_inversion,a.mto_inversion 
  from cb_prv_genericas a 
where a.tip_riesgo = 5 
  and a.sec_inversion = 4 
  and a.mto_inversion > 0;

--Obtengo los datos de los tipos de riesgos y sectores de riesgos para calcular el valor de la previsión genérica.
cursor c_prv_generica is
select a.tip_riesgo,a.sec_riesgo, sum(a.mto_inversion) mto_total
  from cb_prv_genericas a 
group by a.tip_riesgo,a.sec_riesgo;

--Obtengo el saldo del inventario contable
function lf_obt_sal_inventario(p_gru_rubro cb_par_prv_genericas.cod_gru_rubro%type)
return number
as
v_sal_total      cb_sal_inventarios.sal_total%type default 0;
v_sal_inventario cb_sal_inventarios.sal_total%type default 0;
v_sal_contable   cb_sal_inventarios.sal_total%type default 0;
v_fecha          ge_calendarios.fec_actual%type;

cursor c_rubros is
select cg.cod_rubro 
  from cb_gru_rubros_det cg 
 where cg.cod_gru_rubro = p_gru_rubro;

begin
   
   v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_sal_total := 0;
   for reg in c_rubros loop
       select nvl(sum(a.sal_total),0)
          into v_sal_inventario
        from cb_sal_inventarios a
        where a.cod_rubro = reg.cod_rubro;

       Begin
         select nvl(a.sal_mon_loc_ant,0) + nvl(a.deb_mon_local,0) - nvl(a.cre_mon_local,0)
             into v_sal_contable
           from cb_sal_consolidados a
          where a.cod_rubro = reg.cod_rubro
            and a.ano = to_char(v_fecha,'yyyy')
            and a.mes = to_char(v_fecha,'mm');
       exception
         when others then
            v_sal_contable := 0;
       end;
       
       if v_sal_contable != v_sal_inventario then 
          v_sal_total := v_sal_total + v_sal_contable;
       else
          v_sal_total := v_sal_total + v_sal_inventario;
       end if;
   end loop;
   
   return v_sal_total;

exception 
  when others then
     return 0;
end;

--Proceso principal
begin
   -- Eliminar tabla
   delete cb_prv_genericas;
   
   --Genero el proceso
   for reg in c_par_prv_generica loop
       --Obtengo el saldo del inventario
       v_sal_contable := lf_obt_sal_inventario(reg.cod_gru_rubro);
       
       --Inserto en la tabla correspondiente
       Begin
         insert into cb_prv_genericas
           (tip_riesgo, sec_riesgo, sec_inversion, mto_inversion)
         values
           (reg.tip_riesgo, reg.sec_riesgo, reg.sec_inversion, v_sal_contable);
       exception 
          when others then
             null;
       end;       
   end loop;   
   
   --Calculo el saldo ponderado del pasivo contingente.
   for reg in c_pas_contingente loop
       v_porcentaje := nvl(fug_obt_pardinamico('P_POR_SAL_PONDERADO'),1);
       v_sal_ponderado := round(reg.mto_inversion * v_porcentaje,0);
       --Actualizo el valor calculado en la tabla cb_prv_generica
       Begin
         update cb_prv_genericas a
            set a.mto_inversion = v_sal_ponderado
          where a.tip_riesgo = reg.tip_riesgo
            and a.sec_riesgo = reg.sec_riesgo
            and a.sec_inversion = 6;
       exception
         when others then
           null;
       end;
   end loop;
   
   --Calculo el valor de la previsión genérica.
   for reg in c_prv_generica loop
       --Calculo el valor de la previsión de acuerdo al porcentaje.
       v_porcentaje := nvl(fue_obt_des_refcodes('POR_PRV_GENERICA',reg.tip_riesgo),0);
       v_mto_prevision := round((reg.mto_total * v_porcentaje)/100,0);              
       --Actualizo el valor en la tabla.
       Begin
         update cb_prv_genericas a
            set a.mto_prv_generica = v_mto_prevision
          where a.tip_riesgo = reg.tip_riesgo
            and a.sec_riesgo = reg.sec_riesgo;
       exception
         when others then
           null;
       end;
   end loop;
end;
/

