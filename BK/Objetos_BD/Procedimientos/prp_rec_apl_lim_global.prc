create or replace procedure it.prp_rec_apl_lim_global(p_nro_linea in number default null,
                                                   p_tip_linea in varchar2 default 'G',
                                                   p_tip_actualizacion in varchar2 default null ) is
  ------------------------------------------------------
  /**---Objetivo: Actualizacion de Limites Globales--**/
  /**--Creado por rpavon--                           **/
  /**--Modificado por lcabrera_ITC : Marzo/2014      **/
  /** Puesta en producción estimada para Mayo/2015   **/
  /**--p_tip_linea G- Global / I- Individual         **/
  ------------------------------------------------------
  v_mto_ope_especifica     pr_gru_lineas.mto_ope_especificas%type := 0;
  v_mto_aplicado           pr_gru_lineas.mto_aplicado%type := 0;
  v_est_lin_global         pr_gru_lineas.estado%type := 'X';
  v_val_lin_aplicar        varchar2(240);
  v_men_err_apl_linea      varchar2(240);
  v_lugar                  varchar2(240);
  v_nro_lin_glo_obtenido   pr_gru_lineas.nro_linea%type;
  v_det_error              varchar2(200);
  v_sal_global             pr_gru_lineas.monto%type := 0;
  v_sal_gar_global         pr_gru_lineas.monto%type := 0;
  v_sal_gar_pro_global     pr_gru_lineas.monto%type := 0;
  v_mto_apl_acumulado      pr_gru_lineas.monto%type := 0;


    cursor c_lin_invididual(p_lin_global pr_gru_lineas.nro_linea%type) is
    select nro_lin_global,
           nro_lin_individual,
           cod_persona,
           cod_gru_economico,
           cod_moneda,
           est_lim_individual,
           apl_lim_individual
      from (select lg.nro_linea        nro_lin_global,
                   li.nro_linea        nro_lin_individual,
                   li.cod_persona      cod_persona,
                   g.cod_gru_economico cod_gru_economico,
                   lg.cod_moneda       cod_moneda,
                   li.estado           est_lim_individual,
                   nvl(pag_gen.FU_CON_MON_A_MONEDA(li.cod_moneda,
                                                       lg.cod_moneda,
                                                       nvl(li.mto_aplicado, 0)),
                                                       0) apl_lim_individual
              from pr_gru_lin_aplicaciones pl,
                   pr_gru_lineas           lg,
                   ge_clientes             g,
                   pr_lineas               li
             where pl.nro_linea = lg.nro_linea
               and pl.cod_persona = g.cod_persona
               and lg.cod_gru_economico = g.cod_gru_economico
               and li.cod_persona = g.cod_persona
               and lg.nro_linea = p_lin_global
               and li.estado in ('A','B','P')
            union all
            select lg.nro_linea        nro_lin_global,
                   li.nro_linea        nro_lin_individual,
                   li.cod_persona      cod_persona,
                   g.cod_gru_economico cod_gru_economico,
                   lg.cod_moneda       cod_moneda,
                   li.estado           est_lin_individual,
                   nvl(pag_gen.FU_CON_MON_A_MONEDA(li.cod_moneda,
                                                       lg.cod_moneda,
                                                       nvl(li.mto_aplicado, 0)),
                                                       0) apl_lim_individual
              from pr_gru_lineas lg, ge_clientes g, pr_lineas li
             where lg.cod_gru_economico = g.cod_gru_economico
               and li.cod_persona = g.cod_persona
               and lg.nro_linea = p_lin_global
               and li.estado in ('A','B','P')
               and not exists
             (select 1
                      from pr_gru_lin_aplicaciones pl
                     where pl.nro_linea = lg.nro_linea
                       and pl.cod_persona = g.cod_persona))
     order by nro_lin_global, est_lim_individual, nro_lin_individual;

  cursor c_ope_garantias (p_nro_lin_individual pr_lineas.nro_linea%type,
                          p_nro_lin_global     pr_gru_lineas.nro_linea%type)is
    Select gr.nro_linea nro_lin_global,
           o.cod_garantia,
           o.mto_limite,
           nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(l.cod_moneda,
                                               gr.cod_moneda,
                                               nvl(o.mto_aplicado, 0))),
               0) mto_aplicado
      from pr_lin_tip_garantias o, ge_clientes g, pr_gru_lineas gr, pr_lineas l
     where l.cod_persona = g.cod_persona
       and o.nro_linea = l.nro_linea
       and gr.cod_gru_economico = nvl(g.cod_gru_economico, 0)
       and gr.nro_linea = p_nro_lin_global
       and l.nro_linea = p_nro_lin_individual
       and exists (select 1
              from pr_gru_lin_aplicaciones pl
             where pl.nro_linea = gr.nro_linea
               and pl.cod_persona = pl.cod_persona)
       and l.estado in ('A','B','P')
     Group by gr.nro_linea, o.cod_garantia, o.mto_limite;

  cursor c_ope_gar_modalidad (p_nro_lin_individual pr_lineas.nro_linea%type,
                              p_nro_lin_global     pr_gru_lineas.nro_linea%type)is
   Select gr.nro_linea nro_lin_global,
           o.cod_garantia,
           o.cod_modulo,
           nvl(o.cod_modalidad, 0) cod_modalidad,
           nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(l.cod_moneda,
                                               gr.cod_moneda,
                                               nvl(o.mto_aplicado, 0))),
               0) mto_aplicado
      from pr_lin_tip_gar_mad o, ge_clientes g, pr_gru_lineas gr, pr_lineas l
     where l.cod_persona = g.cod_persona
       and o.nro_linea = l.nro_linea
       and gr.cod_gru_economico = nvl(g.cod_gru_economico, 0)
       and gr.nro_linea = p_nro_lin_global
       and l.nro_linea = p_nro_lin_individual
       and l.estado in ('A','B','P')
       and exists (select 1
              from pr_gru_lin_aplicaciones pl
             where pl.nro_linea = gr.nro_linea
               and pl.cod_persona = pl.cod_persona)
     Group by gr.nro_linea,
              o.cod_garantia,
              o.cod_modulo,
              nvl(o.cod_modalidad, 0);

------------Inicio declaración de Funciones y Procesos Internos -----------------------------------
function lf_obt_nro_lin_global return number is
v_nro_lin_global      pr_gru_lineas.nro_linea%type;
begin
if p_tip_linea = 'G' then
 v_nro_lin_global := p_nro_linea;
else
  begin
    select lg.nro_linea
      into v_nro_lin_global
      from pr_gru_lineas lg, ge_clientes g, pr_lineas li
     where lg.cod_gru_economico = g.cod_gru_economico
       and li.cod_persona = g.cod_persona
       and p_tip_linea = 'I'
       and li.nro_linea = p_nro_linea
       and lg.estado in ('P');
  exception
    when no_data_found then
      begin
        select lg.nro_linea
          into v_nro_lin_global
          from pr_gru_lineas lg, ge_clientes g, pr_lineas li
         where lg.cod_gru_economico = g.cod_gru_economico
           and li.cod_persona = g.cod_persona
           and p_tip_linea = 'I'
           and li.nro_linea = p_nro_linea
           and lg.estado in ('A', 'B');
      exception
        when no_data_found then
          v_nro_lin_global := 0;
        when others then
          v_nro_lin_global := 0;
      end;
    when others then
      v_nro_lin_global := 0;
  end;
end if;
  return v_nro_lin_global;
end;


function lf_obt_sal_limite(p_nro_global in pr_gru_lineas.nro_linea%type)return number is

v_saldo   pr_gru_lineas.monto%type;

begin
  begin
    ---obtener totales de linea global
    select nvl(pr.monto, 0) - nvl(pr.mto_aplicado,0)
      into v_saldo
      from pr_gru_lineas pr
     where pr.nro_linea = p_nro_global;
  exception
    when no_data_found then
      v_saldo := 0;
    when others then
      v_saldo := 0;
  end;
  return v_saldo;
end lf_obt_sal_limite;

---Funcion que obtiene saldo por código de garantía
function lf_obt_sal_gar_limite(p_nro_global in pr_gru_lineas.nro_linea%type,
                               p_cod_garantia  in pr_gru_lin_tip_garantias.cod_garantia%type)
                               return number is

v_sal_garantia  pr_gru_lin_tip_garantias.mto_limite%type;

begin
  begin
    ---obtener totales de linea global
    select nvl(gr.mto_limite, 0) - nvl(gr.mto_aplicado,0)
      into v_sal_garantia
      from pr_gru_lin_tip_garantias gr
     where gr.nro_linea = p_nro_global
       and gr.cod_garantia = p_cod_garantia;
  exception
    when no_data_found then
      v_sal_garantia := 0;
    when others then
      v_sal_garantia := 0;
  end;
  return v_sal_garantia;
end lf_obt_sal_gar_limite;

----Función que obtiene el saldo por garantia por producto
function lf_obt_sal_gar_pro_limite(p_nro_global in pr_gru_lineas.nro_linea%type,
                               p_cod_garantia  in pr_gru_lin_tip_gar_mad.cod_garantia%type,
                               p_cod_modulo    in pr_gru_lin_tip_gar_mad.cod_modulo%type,
                               p_cod_modalidad in pr_gru_lin_tip_gar_mad.cod_modalidad%type)
                               return number is

v_sal_gar_mad  pr_gru_lin_tip_garantias.mto_limite%type;

begin
  begin
    ---obtener totales de linea global
    select nvl(lpr.mto_limite, 0) - nvl(lpr.mto_aplicado,0)
      into v_sal_gar_mad
      from pr_gru_lin_tip_gar_mad lpr
     where lpr.nro_linea = p_nro_global
       and lpr.cod_garantia = p_cod_garantia
       and lpr.cod_modulo = nvl(p_cod_modulo,0)
       and lpr.cod_modalidad = nvl(p_cod_modalidad,0);
  exception
    when no_data_found then
        begin
          ---obt total limite por modulo
          select sum(nvl(lpr.mto_limite, 0))
            into v_sal_gar_mad
            from pr_gru_lin_tip_gar_mad lpr
           where lpr.nro_linea = p_nro_global
             and lpr.cod_garantia = p_cod_garantia
             and lpr.cod_modulo = nvl(p_cod_modulo, 0);
        exception
          when no_data_found then
                begin
                  ---verifica si existe al menos una configuracion
                  select distinct 0
                    into v_sal_gar_mad
                    from pr_gru_lin_tip_gar_mad lpr
                   where lpr.nro_linea = p_nro_global;
                exception
                  when no_data_found then
                    v_sal_gar_mad := - 99;
                  when others then
                    v_sal_gar_mad := - 98;
                end;
          when others then
            v_sal_gar_mad := - 98;
        end;
    when others then
      v_sal_gar_mad := 0;
  end;
  return v_sal_gar_mad;
end lf_obt_sal_gar_pro_limite;


function lf_obt_cod_persona(p_nro_lin  pr_lineas.nro_linea%type)return number is
v_cod_persona      pr_lineas.cod_persona%type;
begin
    if p_nro_lin is not null then
      begin
        select li.cod_persona
          into v_cod_persona
          from pr_lineas li
         where li.nro_linea = p_nro_lin;
      exception
        when no_data_found then
          v_cod_persona := 0;
          return v_cod_persona;
        when others then
          v_cod_persona := 0;
          return v_cod_persona;
      end;
      return v_cod_persona;
    end if;
exception
  when no_data_found then
     v_cod_persona := 0;
     return v_cod_persona;
  when others then
     v_cod_persona := 0;
    return v_cod_persona;
end lf_obt_cod_persona;

procedure lp_ins_log_error(p_det_error pr_log_errores.det_error%type) is
---Insertar datos del error identificado
 PRAGMA AUTONOMOUS_TRANSACTION;
begin
  insert into pr_log_errores (det_error)
       values (p_det_error);
       commit;

exception
  when others then
     raise_application_error(-20000, 'Error: Al intentar registrar log de Error: ' || p_det_error ||sqlerrm);
end lp_ins_log_error;

procedure lp_del_log_error is
---Insertar datos del error identificado
 PRAGMA AUTONOMOUS_TRANSACTION;
begin
  delete from pr_log_errores lg
   where trunc(lg.fec_insercion) < trunc(sysdate - 15);
  commit;

exception
  when others then
    raise_application_error(-20000,'Error: Al intentar BORRAR log de Errores: '||sqlerrm);
end lp_del_log_error;


procedure lp_act_lim_no_aplicado (p_nro_lin_global       pr_gru_lineas.nro_linea%type,
                                  p_nro_lin_individual   pr_lineas.nro_linea%type,
                                  p_est_aplicacion       pr_gru_lin_aplicaciones.estado%type)is
---Actualizar Límite Individual No Aplicado al Lím. Global
 PRAGMA AUTONOMOUS_TRANSACTION;
begin
    update pr_gru_lin_aplicaciones apl
       set apl.estado = p_est_aplicacion
     where apl.nro_linea = p_nro_lin_global
       and apl.nro_lin_individual = p_nro_lin_individual;
    commit;

exception
  when others then
    raise_application_error(-20000,'Error: Actualizar Lim. Ind. No Aplicado: '||p_nro_lin_individual||sqlerrm);
end lp_act_lim_no_aplicado;


------------FIN declaración de Funciones y Procesos Internos -----------------------------------


begin
 --Inicio controles antes de realizar actualizaciones
 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
    v_nro_lin_glo_obtenido := lf_obt_nro_lin_global;

---Se limpia tabla log de errores tomando datos de 15 días atras
lp_del_log_error;

if v_nro_lin_glo_obtenido != 0 then


   v_lugar:='PRP_REC_APL_LIM_GLOBAL - Obtener Estado de la Línea Global - pr_gru_lineas';
   Begin
     select lg.estado
       into v_est_lin_global
       from pr_gru_lineas lg
      where lg.nro_linea = v_nro_lin_glo_obtenido for update nowait;
   exception
     when no_data_found then
       v_est_lin_global := 'P';
     when too_many_rows then
       v_est_lin_global := 'P';
     when others then
       IF sqlcode = -54 THEN
          raise_application_error(-20000, 'Proc. Recalculo Lím. Global. Linea: ' || 
                                       p_nro_linea ||' - Tipo: '||p_tip_linea|| ' Bloqueado por otro usuario.' );
       END IF;
       v_lugar := 'Error al:' || v_lugar || '-' ||'Otros Errores encontrados';
       lp_ins_log_error(v_lugar);
       raise_application_error(-20001,v_lugar);
   end;


    If v_est_lin_global = 'B' and nvl(p_tip_actualizacion,'N') = 'N' then
        v_lugar := 'Linea Global Bloqueada no puede utilizar. Nro.'||v_nro_lin_glo_obtenido;
        lp_ins_log_error(v_lugar);
        raise_application_error(-20001,v_lugar);
    elsif v_est_lin_global in ('P') and nvl(p_tip_actualizacion,'N')  = 'N' then
        v_lugar := 'Linea Global No esta Aprobada no puede utilizar. Nro.'||v_nro_lin_glo_obtenido;
        lp_ins_log_error(v_lugar);
        raise_application_error(-20001,v_lugar);
    end if;
    if pae_cnf.g_programa not in ('GPPROFIN', 'PMAPRLIM') then
        for c_lin_ind in c_lin_invididual(v_nro_lin_glo_obtenido) loop
            prp_rec_apl_limite(c_lin_ind.nro_lin_individual);
            lp_act_lim_no_aplicado(v_nro_lin_glo_obtenido,c_lin_ind.nro_lin_individual,'A');
         end loop;
     end if;

    v_lugar:= 'Inician las actualizaciones si se dan las condiciones';
    if v_est_lin_global in ('A','C','P','B') then
     -----Se limpian todos los valores
     for c_lin_ind in c_lin_invididual(v_nro_lin_glo_obtenido) loop
      if c_lin_ind.nro_lin_global is not null then
         begin
           v_lugar:= 'PRP_REC_APL_LIM_GLOBAL - Cerar la Linea Global - pr_gru_lineas: '||v_nro_lin_glo_obtenido;
            update pr_gru_lineas
               set mto_aplicado = 0
             where nro_linea = c_lin_ind.nro_lin_global;
         exception
           when no_data_found then
             null;
           when others then
              v_lugar := v_lugar || 'Línea Global: '||c_lin_ind.nro_lin_global;
              lp_ins_log_error(v_lugar);
              raise_application_error(-20001,v_lugar);
         end;

         begin
          v_lugar:= 'PRP_REC_APL_LIM_GLOBAL - Cerar la Linea Global - pr_gru_lin_tip_garantias '||v_nro_lin_glo_obtenido;
            update pr_gru_lin_tip_garantias
               set mto_aplicado = 0
             where nro_linea = c_lin_ind.nro_lin_global;
         exception
           when no_data_found then
             null;
           when others then
              v_lugar := v_lugar || 'Línea Global: '||c_lin_ind.nro_lin_global;
              lp_ins_log_error(v_lugar);
              raise_application_error(-20001,v_lugar);
         end;


         begin
          v_lugar:='PRP_REC_APL_LIM_GLOBAL - Cerar la Linea Global - pr_gru_lin_tip_gar_mad '||v_nro_lin_glo_obtenido;
            update pr_gru_lin_tip_gar_mad
               set mto_aplicado = 0
             where nro_linea = c_lin_ind.nro_lin_global;
         exception
           when no_data_found then
             null;
           when others then
              v_lugar := v_lugar || 'Línea Global: '||c_lin_ind.nro_lin_global;
              lp_ins_log_error(v_lugar);
              raise_application_error(-20001,v_lugar||sqlerrm);
         end;

      end if;
     end loop;
      v_sal_global := 0;
      v_sal_global := lf_obt_sal_limite(v_nro_lin_glo_obtenido);
      ---Para controlar Saldo Lím. Global Vs. Monto Aplicado de Límite Individual
      for c_lin_ind in c_lin_invididual (v_nro_lin_glo_obtenido)loop
       if c_lin_ind.nro_lin_global is not null then
           v_mto_aplicado := c_lin_ind.apl_lim_individual;
           v_mto_apl_acumulado := v_mto_apl_acumulado + v_mto_aplicado;
           if v_sal_global >= v_mto_apl_acumulado then
              begin
                 v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Actualización pr_gru_lineas';
                  update pr_gru_lineas y
                     set y.mto_aplicado   = y.mto_aplicado + v_mto_aplicado
                   where y.nro_linea      = c_lin_ind.nro_lin_global
                     and y.monto - y.mto_aplicado >= y.mto_aplicado + v_mto_aplicado;

               exception
                  when others then
                       v_lugar:= v_lugar ||'Error: Lím. Global: ' || c_lin_ind.nro_lin_global
                                         ||'- Lím. Individual: '||c_lin_ind.nro_lin_individual ||v_lugar;
                      lp_ins_log_error(v_lugar);
                      lp_act_lim_no_aplicado(c_lin_ind.nro_lin_global,c_lin_ind.nro_lin_individual,'N');
                      raise_application_error(-20001,v_lugar);
                end;
             else
                      v_lugar:= 'Error: Lím. Global: ' || c_lin_ind.nro_lin_global  ||'- Cliente: '||lf_obt_cod_persona(c_lin_ind.nro_lin_individual)
                                                 || ' Saldo Lím. Global Insuficiente para Monto Aplicado de Lím. Individuales';
                      lp_act_lim_no_aplicado(c_lin_ind.nro_lin_global,c_lin_ind.nro_lin_individual,'N');
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
             end if;
        end if;
     end loop;


      ---Se recalcula todos los valores
      for c_lin_ind in c_lin_invididual (v_nro_lin_glo_obtenido)loop

       if c_lin_ind.nro_lin_global is not null then

           prp_val_con_gru_lineas(c_lin_ind.nro_lin_individual, c_lin_ind.nro_lin_global,v_val_lin_aplicar,v_det_error );

          if v_val_lin_aplicar IN (0,8) then

            for c_ope_gar_mad in c_ope_gar_modalidad (c_lin_ind.nro_lin_individual,c_lin_ind.nro_lin_global) loop
             v_sal_gar_pro_global := lf_obt_sal_gar_pro_limite (c_lin_ind.nro_lin_global,c_ope_gar_mad.cod_garantia,
                                                        c_ope_gar_mad.cod_modulo, c_ope_gar_mad.cod_modalidad);

             If v_sal_gar_pro_global != -99 then  ---Se agrega esta condición para los lim globales sin config de gar x prod
                 If v_sal_gar_pro_global >= c_ope_gar_mad.mto_aplicado  then
                    begin
                        v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Actualizar pr_gru_lin_tip_gar_mad por Mod/. y Modal. ';
                        update pr_gru_lin_tip_gar_mad md
                           set md.mto_aplicado = md.mto_aplicado +
                                                 c_ope_gar_mad.mto_aplicado
                         where md.nro_linea = c_ope_gar_mad.nro_lin_global
                           and md.cod_garantia = c_ope_gar_mad.cod_garantia
                           and md.cod_modulo = c_ope_gar_mad.cod_modulo
                           and md.cod_modalidad = c_ope_gar_mad.cod_modalidad;

                      IF SQL%NOTFOUND THEN
                        v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Actualizar pr_gru_lin_tip_gar_mad por Modulo. ';
                        update pr_gru_lin_tip_gar_mad md
                           set md.mto_aplicado = md.mto_aplicado +
                                                 c_ope_gar_mad.mto_aplicado
                         where md.nro_linea = c_ope_gar_mad.nro_lin_global
                           and md.cod_garantia = c_ope_gar_mad.cod_garantia
                           and md.cod_modulo = c_ope_gar_mad.cod_modulo;
                      END IF;

                    exception
                      when others then
                          v_lugar := 'Error: linea: '||c_ope_gar_mad.nro_lin_global||'-'|| v_lugar;
                          lp_ins_log_error(v_lugar);
                          raise_application_error(-20001,v_lugar);
                    end;
                 else
                      v_lugar := 'Monto Aplicado de Lim. Ind. Mayor a Lim. Global - Cliente: ' || lf_obt_cod_persona(c_lin_ind.nro_lin_individual) || '-' ||
                                                    'Garantía: ' || fup_obt_des_tip_garantia(c_ope_gar_mad.cod_garantia)|| '-' ||
                                                    'Prod.: ' ||c_ope_gar_mad.cod_modulo||'-'||c_ope_gar_mad.cod_modalidad;
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
                 end if;
             End if;
            end loop;

            for c_ope_gar in c_ope_garantias (c_lin_ind.nro_lin_individual,c_lin_ind.nro_lin_global) loop

             v_sal_gar_global := lf_obt_sal_gar_limite (c_ope_gar.nro_lin_global, c_ope_gar.cod_garantia);

            If v_sal_gar_global >= c_ope_gar.mto_aplicado then
                begin
                  v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Actualizar pr_gru_lin_tip_garantias ';
                  update pr_gru_lin_tip_garantias gl
                     set gl.mto_aplicado = nvl(gl.mto_aplicado,0) + c_ope_gar.mto_aplicado
                   where gl.nro_linea = c_ope_gar.nro_lin_global
                     and gl.cod_garantia = c_ope_gar.cod_garantia;
                exception
                  when others then
                      v_lugar:= v_lugar ||' Error: linea: '||c_ope_gar.nro_lin_global||'-'|| v_lugar;
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
                end;
             else
                      v_lugar:= v_lugar ||'Monto Aplicado de Lim. Ind. Mayor a Lim. Global - Cliente: ' || lf_obt_cod_persona(c_lin_ind.nro_lin_individual)|| '-' ||
                                                'Garantía: ' || fup_obt_des_tip_garantia(c_ope_gar.cod_garantia);
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
             end if;


            end loop;

          else

            v_men_err_apl_linea := fue_obt_des_refcodes('TIP_RTA_VER_LINEA', v_val_lin_aplicar)||'-'||v_det_error;
            lp_ins_log_error(v_men_err_apl_linea);
            lp_act_lim_no_aplicado(c_lin_ind.nro_lin_global,c_lin_ind.nro_lin_individual,'N');
            raise_application_error(-20001,v_lugar);
          end if;

       end if;


      end loop;

           if v_val_lin_aplicar IN (0,8) then

              if v_nro_lin_glo_obtenido is not null then
                    Begin
                      v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Obtener Montos para la Linea Global - pr_gru_lineas';
                      select nvl(fup_obt_tot_ope_esp_apl_gru(gr.cod_moneda, gr.cod_gru_economico,'E'),0),
                             nvl(fup_obt_tot_ope_esp_apl_gru(gr.cod_moneda,gr.cod_gru_economico,'A'),0)
                        into v_mto_ope_especifica, v_mto_aplicado
                        from pr_gru_lineas gr
                       where gr.nro_linea = v_nro_lin_glo_obtenido;
                    exception
                      when others then
                        v_lugar := v_lugar || 'Línea Global: ' || v_nro_lin_glo_obtenido;
                        lp_ins_log_error(v_lugar);
                        raise_application_error(-20001, v_lugar);
                    end;
                      v_sal_global := lf_obt_sal_limite(v_nro_lin_glo_obtenido);
               end if;
                begin
                  v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Cerar la Linea Global - pr_gru_lineas: ' ||v_nro_lin_glo_obtenido;
                  update pr_gru_lineas
                     set mto_aplicado = 0
                   where nro_linea = v_nro_lin_glo_obtenido;
                exception
                  when no_data_found then
                    null;
                  when others then
                    v_lugar := v_lugar || 'Línea Global: ' || v_nro_lin_glo_obtenido;
                    lp_ins_log_error(v_lugar);
                    raise_application_error(-20001, v_lugar);
                end;


              v_sal_global := lf_obt_sal_limite(v_nro_lin_glo_obtenido);

             if v_sal_global >= v_mto_aplicado then
                  begin
                   v_lugar := 'PRP_REC_APL_LIM_GLOBAL - Actualización pr_gru_lineas';
                    update pr_gru_lineas y
                       set y.mto_ope_especificas = v_mto_ope_especifica,
                           y.mto_aplicado        = v_mto_aplicado
                     where y.nro_linea = v_nro_lin_glo_obtenido
                       and y.monto - y.mto_aplicado >= v_mto_aplicado;
                  exception
                    when others then
                      v_lugar:= v_lugar ||'Error: Lím. Global: ' || v_nro_lin_glo_obtenido ||v_lugar ;
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
                  end;
               else
                      v_lugar:= 'Error: linea: ' || v_nro_lin_glo_obtenido
                                                 || ' Saldo Lím. Global Insuficiente para Monto Aplicado de Lím. Individuales';
                      lp_ins_log_error(v_lugar);
                      raise_application_error(-20001,v_lugar);
               end if;

            end if;



    end if;
end if;

  if v_val_lin_aplicar != 0 then
       v_men_err_apl_linea := fue_obt_des_refcodes('TIP_RTA_VER_LINEA', v_val_lin_aplicar)||'-'||v_det_error;
       lp_ins_log_error(v_men_err_apl_linea);
       raise_application_error(-20001,v_lugar||'-'||v_men_err_apl_linea);
  end if;

end prp_rec_apl_lim_global;
/

