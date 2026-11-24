create or replace procedure it.prp_rec_cat_ren_resol4 is

--------------------------------------------------------------------------------------------
--Proposito del proceso: realizar recalculo de Categorias de Renovación de Cuentas COVID ---
--------------------------------------------------------------------------------------------

--Necesarios para Categorias se calcula dentro del proceso
v_sub_cat_individual  pr_cta_pre_can_res4.sub_cat_individual%type;
v_cat_renovaciones    pr_cta_pre_ref_res4.cat_ren_cta_nueva%type;

--Switch - ON(S) - OFF (N) para borrado
v_bor_dat_habilitado  ge_par_dinamicos.val_parametro%type;            
--Switch - ON(S) - OFF (N) para Actualización
v_fun_act_habilitado  ge_par_dinamicos.val_parametro%type;            
--Switch - ON(S) - OFF (N) para Analizar
v_fun_ana_habilitado  ge_par_dinamicos.val_parametro%type;            

--Necesarios para Analisis
--Cientes y Cuentas In (debe configurarse entre comas)
v_cli_analizar     ge_par_dinamicos.val_parametro%type;
v_cta_analizar     ge_par_dinamicos.val_parametro%type;

--Necesarios para Actualización (debe configurarse entre comas)
v_cli_actualizar     ge_par_dinamicos.val_parametro%type;
v_cli_no_actualizar  ge_par_dinamicos.val_parametro%type;
v_cta_actualizar     ge_par_dinamicos.val_parametro%type;
v_cta_no_actualizar  ge_par_dinamicos.val_parametro%type;


Cursor c_dat_categorias is
   select cl.cod_persona cod_cliente,
          cl.cat_riesgo  cat_riesgo,
          cl.fecha       fec_dat_cliente,
          e.nro_cuenta   nro_cta_Nueva,
          e.fec_inicio
     from pr_cta_prestamos e, ge_par_dinamicos g,
          ge_cta_clientes gcta, ge_clientes_his cl
    where e.nro_cuenta = gcta.nro_cuenta
      and gcta.cod_persona = cl.cod_persona
      and gcta.relacion = 'P'
      and g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.estado not in ('N','I')
      and cl.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (e.fec_inicio,31,1)
      and (v_cli_analizar is null 
           or 
           instr(','||v_cli_analizar||',',','||cl.cod_persona||',') > 0)
      and (v_cta_analizar is null 
           or 
           instr(','||v_cta_analizar||',',','||e.nro_cuenta||',') > 0) ;



 /*Objetivo de SCRIPT: Forzar herencia de Categoria Automatica en Categoria de Renovaciones */
Cursor c_ctas_inconsistentes is
select nro_cta_original,
       Cat_aut_Cta_Original,
       Cat_ren_Cta_Original,
       cod_modulo,
       cod_modalidad,
       cod_moneda,
       cod_oficina,
       estado,
       nro_cta_Nueva,
       Cat_ren_cta_nueva,
       fec_inicio
from(
 select p.nro_cuenta nro_cta_original,
          h.cat_automatica Cat_aut_Cta_Original,
          h.cat_renovaciones Cat_ren_Cta_Original,
          p.cod_modulo,
          p.cod_modalidad,
          p.cod_moneda,
          p.cod_oficina,
          p.estado,
          e.nro_cuenta nro_cta_Nueva,
          e.cat_renovaciones Cat_ren_cta_nueva,
          e.fec_inicio
     from pr_cta_prestamos p, ge_par_dinamicos g, ge_cla_operaciones_his h,
          pr_cta_pre_can_res4 r , pr_cta_prestamos e
    where g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.nro_cuenta = r.nro_cta_nueva
      and p.nro_cuenta = r.nro_cuenta
      and p.nro_cuenta = h.nro_cuenta
      and p.cod_modulo = h.cod_modulo
      and p.cod_modalidad = h.cod_modalidad
      and h.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (e.fec_inicio,31,1)
      and (v_cli_analizar is null 
           or 
           instr(','||v_cli_analizar||',',','||h.cod_persona||',') > 0)
      and (v_cta_analizar is null 
           or 
           instr(','||v_cta_analizar||',',','||h.nro_cuenta||',') > 0)      
union

   select p.nro_cuenta nro_cta_original,
          h.cat_automatica Cat_aut_Cta_Original,
          h.cat_renovaciones Cat_ren_Cta_Original,
          p.cod_modulo,
          p.cod_modalidad,
          p.cod_moneda,
          p.cod_oficina,
          p.estado,
          e.nro_cuenta nro_cta_Nueva,
          e.cat_renovaciones Cat_ren_cta_nueva,
          e.fec_inicio
     from pr_cta_prestamos p, ge_par_dinamicos g, ge_cla_operaciones_his h,
          pr_cta_pre_ref_res4 r , pr_cta_prestamos e
    where g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.nro_cuenta = r.nro_cta_nueva
      and p.nro_cuenta = r.nro_cuenta
      and p.nro_cuenta = h.nro_cuenta
      and p.cod_modulo = h.cod_modulo
      and p.cod_modalidad = h.cod_modalidad
      and h.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (e.fec_inicio,31,1)
      and (v_cli_analizar is null 
           or 
           instr(','||v_cli_analizar||',',','||h.cod_persona||',') > 0)
      and (v_cta_analizar is null 
           or 
           instr(','||v_cta_analizar||',',','||h.nro_cuenta||',') > 0)         
      ) x
     order by nro_cta_Nueva, Cat_aut_Cta_Original;


function lf_obt_cat_individual(p_cod_persona ge_cla_operaciones_his.cod_persona%type,
                               p_fecha       ge_cla_operaciones_his.fecha%type) return number is

 v_categoria      ge_cla_operaciones.cat_automatica%type;
 v_sub_cat_ind    ge_cla_operaciones.cat_automatica%type;
 v_riesgo1a       pr_parametros.por_riesgo_1a%type ;
 v_riesgo1b       pr_parametros.por_riesgo_1b%type := fug_con_numero(1.2);
 
begin
   --Verifico las operaciones que posee el cliente.
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04
   SELECT nvl(MAX(c.cat_automatica),1)
     INTO v_categoria
     FROM ge_cla_operaciones_his c
    WHERE c.cod_persona = P_COD_PERSONA
      and c.fecha = p_fecha
      and not exists (select 1
                        from ge_par_dinamicos g
                       where g.parametro = 'COD_MAD_RESOLUCION04'
                         and g.val_parametro = 'S'
                         and g.cod_modulo = c.cod_modulo
                         and g.cod_modalidad = c.cod_modalidad);

  if  v_categoria >= 2 then
    v_sub_cat_ind := v_riesgo1b;
  else
    v_sub_cat_ind := v_categoria;
  end if;
  RETURN v_sub_cat_ind;

EXCEPTION
   WHEN OTHERS THEN
      v_sub_cat_ind := 1;
      RETURN v_sub_cat_ind;
end;

procedure lp_ins_rec_tmp is 
v_can_registros    number;
v_truncate         varchar2(200);  
PRAGMA AUTONOMOUS_TRANSACTION;

begin
   
 begin
   select nvl(count(*), 0) 
     into v_can_registros 
     from pr_cta_res4_rec_tmp;
 exception
   when no_data_found then
     v_can_registros := 0;
   when others then
     v_can_registros := 0;
 end;

  if v_can_registros < 1 or v_bor_dat_habilitado = 'S' then
     --limpiar tabla
     v_truncate := 'truncate table pr_cta_res4_rec_tmp';
     execute immediate v_truncate;

     --cargar tabla para analizar datos
    insert into pr_cta_res4_rec_tmp(nro_cuenta, cod_persona, nro_cta_nueva, 
                                    cat_aut_cta_origen, cat_ren_cta_origen, 
                                    cat_ren_cta_nueva, fec_ini_cta_nueva, 
                                    cat_rie_cliente, fec_dat_rie_cliente, 
                                    sub_cat_individual, actualizar) 
     select res.nro_cuenta, res.cod_persona, res.nro_cta_nueva, 
            res.cat_aut_cta_origen, res.cat_ren_cta_origen, 
            res.cat_ren_cta_nueva, res.fec_ini_cta_nueva, 
            res.cat_rie_cliente, res.fec_dat_rie_cliente, 
            res.sub_cat_individual, 'N'
       from pr_cta_pre_can_res4 res, pr_cta_prestamos p
      where res.nro_cta_nueva = p.nro_cuenta
        and p.estado not in ('N','I')
        and (v_cli_analizar is null 
             or 
             instr(','||v_cli_analizar||',',','||res.cod_persona||',') > 0)
        and (v_cta_analizar is null 
             or 
             instr(','||v_cta_analizar||',',','||p.nro_cuenta||',') > 0)          
      union all
     select res.nro_cuenta, res.cod_persona, res.nro_cta_nueva, 
            res.cat_aut_cta_origen, res.cat_ren_cta_origen, 
            res.cat_ren_cta_nueva, res.fec_ini_cta_nueva, 
            res.cat_rie_cliente, res.fec_dat_rie_cliente, 
            res.sub_cat_individual, 'N'
       from pr_cta_pre_ref_res4 res, pr_cta_prestamos p
      where res.nro_cta_nueva = p.nro_cuenta
        and p.estado not in ('N','I')
        and (v_cli_analizar is null 
             or 
             instr(','||v_cli_analizar||',',','||res.cod_persona||',') > 0)
        and (v_cta_analizar is null 
             or 
             instr(','||v_cta_analizar||',',','||p.nro_cuenta||',') > 0);
    commit;
  end if;
end;
procedure lp_hab_actualizacion(p_fun_act_habilitada varchar2) is

v_fun_actualizacion ge_par_dinamicos.val_parametro%type:= nvl(p_fun_act_habilitada,'N');

begin


If nvl(v_fun_actualizacion,'N') = 'S' then      
 
 update pr_cta_res4_rec_tmp r
    set r.actualizar = 'N';

  update pr_cta_res4_rec_tmp r
     set r.actualizar = 'S'
    ---Clientes Incluidos en la actualización
   where instr(','||v_cli_actualizar||',',','||r.cod_persona||',') > 0;
     
 update pr_cta_res4_rec_tmp r
     set r.actualizar = 'S'
    ---Ctas Incluidos en la actualización
   where instr(','||v_cta_actualizar||',',','||r.nro_cuenta||',') > 0;     
     

  update pr_cta_res4_rec_tmp r
     set r.actualizar = 'N'
    ---Clientes Excluidos de la actualización
   where instr(','||v_cli_no_actualizar||',',','||r.cod_persona||',') < 1;

  update pr_cta_res4_rec_tmp r
     set r.actualizar = 'N'
    ---Ctas Excluidos de la actualización
   where instr(','||v_cta_no_actualizar||',',','||r.nro_cuenta||',') < 1;

end if;
  
end;

procedure lp_act_categorias is

Cursor c_dat_categorias is
   select tmp.cod_persona cod_cliente,
          tmp.cat_rie_cliente,
          tmp.fec_dat_rie_cliente,
          e.nro_cuenta    nro_cta_Nueva,
          tmp.rec_cat_aut_cta_origen,  
          tmp.rec_cat_ren_cta_origen,
          tmp.rec_cat_ren_cta_nueva,
          tmp.rec_cat_rie_cliente,
          tmp.rec_fec_dat_rie_cliente,
          tmp.rec_sub_cat_individual
     from pr_cta_prestamos e, pr_cta_res4_rec_tmp tmp
    where e.nro_cuenta = tmp.nro_cuenta
      and tmp.actualizar = 'S'
      and tmp.cat_ren_cta_nueva <> tmp.rec_cat_ren_cta_nueva;
  
begin
  
 for c_cat in c_dat_categorias loop
      
      --limpiamos variables para evitar datos sucios
      v_sub_cat_individual := c_cat.rec_sub_cat_individual;
      v_cat_renovaciones   := c_cat.cat_rie_cliente;
      
      update pr_cta_prestamos p
         set p.cat_renovaciones = round(c_cat.cat_rie_cliente,0)
       where p.nro_cuenta       = c_cat.nro_cta_Nueva
         and p.estado <> 'N';

      
      update pr_cta_pre_can_res4 p
         set p.cat_rie_cliente = c_cat.cat_rie_cliente,
             p.fec_dat_rie_cliente  = c_cat.fec_dat_rie_cliente,
             p.sub_cat_individual = v_sub_cat_individual,
             --en este punto asignará cat 1a / 1b si cat riesgo es 1 y la cta ori estaba con atraso
             p.cat_ren_cta_nueva  = nvl(v_sub_cat_individual,v_cat_renovaciones),
             p.cat_aut_cta_origen = c_cat.rec_Cat_aut_Cta_Origen,
             p.cat_ren_cta_origen = c_cat.rec_Cat_ren_Cta_Origen
       where p.nro_cta_nueva = c_cat.nro_cta_Nueva;

      update pr_cta_pre_ref_res4 p
         set p.cat_rie_cliente = c_cat.cat_rie_cliente,
             p.fec_dat_rie_cliente  = c_cat.fec_dat_rie_cliente,
             p.sub_cat_individual = v_sub_cat_individual,
             --en este punto asignará cat 1a / 1b si cat riesgo es 1 y la cta ori estaba con atraso
             p.cat_ren_cta_nueva  = nvl(v_sub_cat_individual,v_cat_renovaciones),
             p.cat_aut_cta_origen = c_cat.rec_Cat_aut_Cta_Origen,
             p.cat_ren_cta_origen = c_cat.rec_Cat_ren_Cta_Origen             
       where p.nro_cta_nueva = c_cat.nro_cta_Nueva;
  
  end loop;  
end;

begin

  v_fun_ana_habilitado := nvl(fug_obt_pardinamico('HAB_FUN_ANA_REC_CAT_COVID'),'N');
  v_fun_act_habilitado := nvl(fug_obt_pardinamico('HAB_FUN_ACT_REC_CAT_COVID'),'N');
  v_bor_dat_habilitado := nvl(fug_obt_pardinamico('BOR_DAT_REC_CAT_COVID'),'N');

  --Necesarios para Analisis
  --Cientes y Cuentas In (debe configurarse entre comas)
  v_cli_analizar     := fug_obt_pardinamico('RES4_CLI_ANA_REC_CAT');
  v_cta_analizar     := fug_obt_pardinamico('RES4_CTA_ANA_REC_CAT');

  --Necesarios para Actualización (debe configurarse entre comas)
  v_cli_actualizar    := fug_obt_pardinamico('RES4_CLI_ACT_REC_CAT');
  v_cli_no_actualizar := fug_obt_pardinamico('RES4_CLI_NO_ACT_REC_CAT');
  v_cta_actualizar    := fug_obt_pardinamico('RES4_CTA_ACT_REC_CAT');
  v_cta_no_actualizar := fug_obt_pardinamico('RES4_CTA_NO_ACT_REC_CAT');



    --Borrar y volver a cargar tabla tmp 
    lp_ins_rec_tmp;

    If v_fun_ana_habilitado = 'S' then 
      ---ReCalcular Categoria AUTOMATICA y RENOVADA DE CUENTA ORIGEN
      for c_pre in c_ctas_inconsistentes loop

          update pr_cta_res4_rec_tmp p
             set p.rec_cat_aut_cta_origen = c_pre.Cat_aut_Cta_Original,
                 p.rec_cat_ren_cta_origen = c_pre.Cat_ren_Cta_Original
           where p.nro_cta_nueva = c_pre.nro_cta_Nueva
             and p.nro_cuenta = c_pre.nro_cta_original;

      end loop;

     --ReCalcular Categoria Según Lógica COVID
     for c_cat in c_dat_categorias loop

          --limpiamos variables para evitar datos sucios
          v_sub_cat_individual := null;
          v_cat_renovaciones   := c_cat.cat_riesgo;

     
          ---Si categoria es menor a 2 se debe obtener cat individual
          if round(c_cat.cat_riesgo,0) < 2 then
             v_sub_cat_individual := lf_obt_cat_individual (c_cat.cod_cliente, c_cat.fec_dat_cliente);
          end if;


          update pr_cta_res4_rec_tmp p
             set p.rec_cat_rie_cliente = c_cat.cat_riesgo,
                 p.rec_fec_dat_rie_cliente  = c_cat.fec_dat_cliente,
                 p.rec_sub_cat_individual = v_sub_cat_individual,
                 --en este punto asignará cat 1a / 1b si cat riesgo es 1 y la cta ori estaba con atraso
                 p.rec_cat_ren_cta_nueva  = nvl(v_sub_cat_individual,v_cat_renovaciones)
           where p.nro_cta_nueva = c_cat.nro_cta_Nueva;


      end loop;
  End if;
  
  If nvl(v_fun_act_habilitado,'N') = 'S' then
    ---Proceso valida parametros para permitir o no actualización
    lp_hab_actualizacion(v_fun_act_habilitado);

    --Proceso realiza actualización segun parametrización
    lp_act_categorias;
  End if;
end;
/

