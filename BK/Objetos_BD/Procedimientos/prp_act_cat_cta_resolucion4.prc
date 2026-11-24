create or replace procedure it.prp_act_cat_cta_resolucion4 is

v_fec_anterior        ge_calendarios.fec_anterior%type;
v_fec_actual          ge_calendarios.fec_actual%type;
v_sub_cat_individual  pr_cta_pre_can_res4.sub_cat_individual%type;
v_cat_max_renovaciones ge_cla_operaciones.cat_automatica%type;
v_cat_rie_1b           ge_cla_operaciones.cat_automatica%type := fug_con_numero('1.2');
v_cat_renovaciones     pr_cta_pre_ref_res4.cat_ren_cta_nueva%type;

--SDRES4COVI-171 - Cuentas Meses de Gracia: se agrega nvl para fec_ini_rrr / fec_inicio

Cursor c_act_categoria is 
   select cl.cod_persona    cod_cliente,
          cl.cat_riesgo     cat_riesgo,
          cl.fecha          fec_dat_cliente,
          e.nro_cuenta      nro_cta_Nueva,  
          nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio,
          e.cod_modulo,
          e.cod_modalidad
      from pr_cta_prestamos e,
           ge_par_dinamicos g,
           ge_cta_clientes  gcta,
           ge_clientes_his  cl
    where e.nro_cuenta = gcta.nro_cuenta
      and gcta.cod_persona = cl.cod_persona
      and gcta.relacion = 'P'
      and g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.estado not in ('N','I')
      and nvl(e.fec_ini_rrr, e.fec_inicio) >= v_fec_anterior
      and cl.fecha = v_fec_anterior
    union
   select cl.cod_persona    cod_cliente,
          cl.cat_riesgo     cat_riesgo,
          v_fec_actual      fec_dat_cliente,
          e.nro_cuenta      nro_cta_Nueva,  
          nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio,
          e.cod_modulo,
          e.cod_modalidad
      from pr_cta_prestamos e,
           ge_par_dinamicos g,
           ge_cta_clientes  gcta,
           ge_clientes      cl
    where e.nro_cuenta = gcta.nro_cuenta
      and gcta.cod_persona = cl.cod_persona
      and gcta.relacion = 'P'
      and g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.estado not in ('N','I')
      and nvl(e.fec_ini_rrr, e.fec_inicio) = v_fec_actual
    union
    select cl.cod_persona cod_cliente,
           cl.cat_riesgo  cat_riesgo,
           cl.fecha       fec_dat_cliente,
           e.nro_cuenta   nro_cta_Nueva,
           nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio,
           e.cod_modulo,
           e.cod_modalidad
      from pr_cta_prestamos e,
           ge_par_dinamicos g,
           ge_cta_clientes  gcta,
           ge_clientes_his  cl
     where e.nro_cuenta = gcta.nro_cuenta
       and gcta.cod_persona = cl.cod_persona
       and gcta.relacion = 'P'
       and g.parametro = 'COD_MAD_RESOLUCION04'
       and e.cod_modulo = g.cod_modulo
       and e.cod_modalidad = g.cod_modalidad
       and e.estado not in ('N', 'I')
       and cl.fecha = pag_cal.FU_OBT_FEC_ANT_HAB(nvl(e.fec_ini_rrr, e.fec_inicio), 31, 1)
       and nvl(e.fec_ini_rrr, e.fec_inicio) < v_fec_anterior
       and exists
     (select distinct 1
              from pr_cta_pre_can_res4 r
             where r.nro_cta_nueva = e.nro_cuenta
               and trunc(r.fec_insercion) = v_fec_actual
            union
            select distinct 1
              from pr_cta_pre_ref_res4 r
             where r.nro_cta_nueva = e.nro_cuenta
               and trunc(r.fec_insercion) = v_fec_actual);
      
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
      from (select p.nro_cuenta       nro_cta_original,
                   h.cat_automatica   Cat_aut_Cta_Original,
                   h.cat_renovaciones Cat_ren_Cta_Original,
                   p.cod_modulo,
                   p.cod_modalidad,
                   p.cod_moneda,
                   p.cod_oficina,
                   p.estado,
                   e.nro_cuenta       nro_cta_Nueva,
                   e.cat_renovaciones Cat_ren_cta_nueva,
                   nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio
              from pr_cta_prestamos       p,
                   ge_par_dinamicos       g,
                   ge_cla_operaciones_his h,
                   pr_cta_pre_can_res4    r,
                   pr_cta_prestamos       e
             where g.parametro = 'COD_MAD_RESOLUCION04'
               and e.cod_modulo = g.cod_modulo
               and e.cod_modalidad = g.cod_modalidad
               and e.nro_cuenta = r.nro_cta_nueva
               and nvl(e.fec_ini_rrr, e.fec_inicio) >= v_fec_anterior
               and p.nro_cuenta = r.nro_cuenta
               and p.nro_cuenta = h.nro_cuenta
               and p.cod_modulo = h.cod_modulo
               and p.cod_modalidad = h.cod_modalidad
               and h.fecha in
                   (select max(x.fecha)
                      from ge_cla_operaciones_his x
                     where x.fecha < nvl(e.fec_ini_rrr, e.fec_inicio)
                       and x.nro_cuenta = r.nro_cuenta)
            union
  select  p.nro_cuenta nro_cta_original,
          h.cat_automatica Cat_aut_Cta_Original,
          h.cat_renovaciones Cat_ren_Cta_Original,
          p.cod_modulo,
          p.cod_modalidad,
          p.cod_moneda,
          p.cod_oficina,
          p.estado,
          e.nro_cuenta nro_cta_Nueva,
          e.cat_renovaciones Cat_ren_cta_nueva,
          nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio
    from  pr_cta_prestamos       p,
          ge_par_dinamicos       g,
          ge_cla_operaciones_his h,
          pr_cta_pre_ref_res4    r,
          pr_cta_prestamos       e
    where g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.nro_cuenta = r.nro_cta_nueva
      and nvl(e.fec_ini_rrr, e.fec_inicio) >= v_fec_anterior
      and p.nro_cuenta = r.nro_cuenta
      and p.nro_cuenta = h.nro_cuenta
      and p.cod_modulo = h.cod_modulo
      and p.cod_modalidad = h.cod_modalidad
               and h.fecha in
                   (select max(x.fecha)
                      from ge_cla_operaciones_his x
                     where x.fecha < nvl(e.fec_ini_rrr, e.fec_inicio)
                       and x.nro_cuenta = r.nro_cuenta)
            union
            select p.nro_cuenta       nro_cta_original,
                   h.cat_automatica   Cat_aut_Cta_Original,
                   h.cat_renovaciones Cat_ren_Cta_Original,
                   p.cod_modulo,
                   p.cod_modalidad,
                   p.cod_moneda,
                   p.cod_oficina,
                   p.estado,
                   e.nro_cuenta       nro_cta_Nueva,
                   e.cat_renovaciones Cat_ren_cta_nueva,
                   nvl(e.fec_ini_rrr, e.fec_inicio) fec_inicio
              from pr_cta_prestamos       p,
                   ge_par_dinamicos       g,
                   ge_cla_operaciones_his h,
                   pr_cta_pre_ref_res4    r,
                   pr_cta_prestamos       e
    where g.parametro = 'COD_MAD_RESOLUCION04'
      and e.cod_modulo = g.cod_modulo
      and e.cod_modalidad = g.cod_modalidad
      and e.nro_cuenta = r.nro_cta_nueva
      and nvl(e.fec_ini_rrr, e.fec_inicio) < v_fec_anterior
      and p.nro_cuenta = r.nro_cuenta
      and p.nro_cuenta = h.nro_cuenta
      and p.cod_modulo = h.cod_modulo
      and p.cod_modalidad = h.cod_modalidad
               and h.fecha in
                   (select max(x.fecha)
                      from ge_cla_operaciones_his x
                     where x.fecha < nvl(e.fec_ini_rrr, e.fec_inicio)
                       and x.nro_cuenta = r.nro_cuenta)
               and exists
             (select distinct 1
                      from pr_cta_pre_ref_res4 r
                     where r.nro_cta_nueva = e.nro_cuenta
                       and trunc(r.fec_insercion) = v_fec_actual)) x
     order by nro_cta_Nueva, Cat_aut_Cta_Original;



  function lf_obt_cat_individual(p_cod_persona ge_cla_operaciones_his.cod_persona%type,
                                 p_fecha       ge_cla_operaciones_his.fecha%type)
    return number is
 v_categoria   ge_cla_operaciones.cat_automatica%type;
                              
begin
   --Verifico las operaciones que posee el cliente.
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04
   SELECT nvl(MAX(c.cat_automatica),1)
     INTO v_categoria
     FROM ge_cla_operaciones_his c
    WHERE c.cod_persona = P_COD_PERSONA
      and c.fecha = p_fecha
       and not exists
     (select 1
                        from ge_par_dinamicos g
                       where g.parametro = 'COD_MAD_RESOLUCION04'
                         and g.val_parametro = 'S'
                         and g.cod_modulo = c.cod_modulo
                         and g.cod_modalidad = c.cod_modalidad);
      RETURN v_categoria;
EXCEPTION
   WHEN OTHERS THEN
      v_categoria := 1;
      RETURN v_categoria;
end;  
     


begin

v_fec_actual   := pag_cal.FU_OBT_FEC_ACTUAL(6);
v_fec_anterior := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual, 31, 1);

  for c_pre in c_ctas_inconsistentes loop
  
    update pr_cta_pre_can_res4 p
       set p.cat_aut_cta_origen = c_pre.Cat_aut_Cta_Original,
             p.cat_ren_cta_origen = c_pre.Cat_ren_Cta_Original,
             p.fec_ini_cta_nueva  = c_pre.fec_inicio
       where p.nro_cta_nueva = c_pre.nro_cta_Nueva
         and p.nro_cuenta = c_pre.nro_cta_original ;

    update pr_cta_pre_ref_res4 p
       set p.cat_aut_cta_origen = c_pre.Cat_aut_Cta_Original,
             p.cat_ren_cta_origen = c_pre.Cat_ren_Cta_Original,
             p.fec_ini_cta_nueva  = c_pre.fec_inicio
       where p.nro_cta_nueva = c_pre.nro_cta_Nueva
         and p.nro_cuenta = c_pre.nro_cta_original ;

  end loop;

  for c_cat in c_act_categoria loop
          
      update pr_cta_prestamos p
         set p.cat_renovaciones = round(c_cat.cat_riesgo,0)
       where p.nro_cuenta = c_cat.nro_cta_Nueva
         and p.estado <> 'N';

    --SDRES4COVI-166-Ajustes Categorización - Previsiones
    --Si categoria Cliente es = 1 se debe obtener cat individual
    v_sub_cat_individual := null;
    v_cat_renovaciones   := c_cat.cat_riesgo;
  
    If round(c_cat.cat_riesgo, 0) = 1 then
      v_cat_max_renovaciones := lf_obt_cat_individual(c_cat.cod_cliente,
                                                      c_cat.fec_dat_cliente);
      If v_cat_max_renovaciones >= 2 then
        v_sub_cat_individual := v_cat_rie_1b;
      Else
        v_sub_cat_individual := v_cat_max_renovaciones;
      End if;
    End if;
    IF (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS', c_cat.cod_modulo, c_cat.cod_modalidad), 'N') = 'S' OR
        nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES', c_cat.cod_modulo, c_cat.cod_modalidad), 'N') = 'S') AND
       (v_sub_cat_individual > 1 AND v_sub_cat_individual < 2) THEN
       v_sub_cat_individual := 1;
    END IF;

       update pr_cta_pre_can_res4 p
         set p.cat_rie_cliente = c_cat.cat_riesgo,
             p.fec_dat_rie_cliente  = c_cat.fec_dat_cliente,
             p.sub_cat_individual = v_sub_cat_individual,
             --en este punto asignará cat 1a / 1b si cat riesgo es 1 y la cta ori estaba con atraso
           p.cat_ren_cta_nueva = nvl(v_sub_cat_individual,
                                     v_cat_renovaciones)
       where p.nro_cta_nueva = c_cat.nro_cta_Nueva;

      update pr_cta_pre_ref_res4 p
         set p.cat_rie_cliente = c_cat.cat_riesgo,
             p.fec_dat_rie_cliente  = c_cat.fec_dat_cliente,
             p.sub_cat_individual = v_sub_cat_individual,
             --en este punto asignará cat 1a / 1b si cat riesgo es 1 y la cta ori estaba con atraso
           p.cat_ren_cta_nueva = nvl(v_sub_cat_individual,
                                     v_cat_renovaciones)
     where p.nro_cta_nueva = c_cat.nro_cta_Nueva;
  
  end loop;

end;
/

