create or replace procedure it.prc_gen_ext_mt940(p_fec_desde in date default pae_cnf.FU_OBT_FEC_ACTUAL(1),
                                                 p_fec_hasta in date default pae_cnf.FU_OBT_FEC_ACTUAL(1)) is

  cursor c_snp_mensajes (p_fec_inicio date
                        ,p_fec_fin    date) is

    select distinct t.campo,
                    t.nro_referencia,
                    t.valor,
                    t.cod_mensaje,
                    trunc(t.fec_insercion) fecha
    from  it.sb_snp_mensajes t
    where t.cod_mensaje    = 'MT940'
    and   t.campo          = '61'
    and   t.nro_linea      = 1
    and   t.valor not like '%FTRFNONREF%'
    and   t.fec_insercion  >= p_fec_inicio
    and   t.fec_insercion  <  p_fec_fin +1;

  cursor c_snp_transferencias (p_fec_inicio date
                              ,p_fec_fin    date) is

    select distinct ':' || t.campo || ':' || t.valor mt_campo,
       s.fecha Fecha,
       s.cod_moneda Moneda,
       nvl(REGEXP_SUBSTR(t.valor, 'C'), REGEXP_SUBSTR(t.valor, 'D')) Tipo,
       to_char(g.monto) Importe,
       g.nro_ref_externa Referencia_BCP,
       to_char(g.cod_msj_swift) Tipo_MT,
       g.nro_referencia,
       g.plataforma,
       g.situacion,
       '' Sal_ini,
       '' sal_fin
    from it.gv_movimientos s, it.ge_snp_transferencias g, it.sb_snp_mensajes t
    where regexp_substr(t.valor, 'F[^//]*') = 'FTRFNONREF'
    and to_char(s.monto) = RTRIM(regexp_substr(RTRIM(replace(regexp_substr(t.valor,(nvl(REGEXP_SUBSTR(t.valor, 'D'), REGEXP_SUBSTR(t.valor, 'C'))) || '[^S]*'),
                 nvl(REGEXP_SUBSTR(t.valor, 'D'), REGEXP_SUBSTR(t.valor, 'C')),''),','), '[^F]*'),',')
    and s.monto = g.monto
    and s.fecha = trunc(t.fec_insercion)
    and s.nro_documento = g.nro_referencia
    and s.fecha = trunc(g.fec_insercion)
    and s.cod_moneda = g.cod_moneda
    and t.cod_mensaje = 'MT940'
    and t.campo = '61'
    and t.nro_linea = 1
    and TRIM(substr(s.CONCEPTO,instr(s.CONCEPTO, 'P',1, 2))) = g.nro_ref_externa
    and s.fecha >= p_fec_inicio
    and s.fecha <  p_fec_fin + 1;

  v_mt_campo        varchar2(2000);
  v_fecha           date;
  v_moneda          varchar2(3);
  v_tipo            varchar2(1);
  v_monto           varchar2(40);
  v_ref_bcp         varchar2(50);
  v_tipo_mt         varchar2(3);
  v_referencia      varchar2(40);
  v_ref_consolidada varchar2(40);
  v_plataforma      varchar2(2);
  v_estado          varchar2(1);
  v_sal_ini         varchar2(50);
  v_sal_fin         varchar2(50);

  PROCEDURE pr_recu_datos (p_val        in  varchar2,
                           p_referencia out varchar2,
                           p_plataforma out varchar2,
                           p_estado     out varchar2) is

  v_valor  varchar2(500);

  begin

    v_valor := SUBSTR(regexp_substr(p_val, 'S[^//]*'),
                (LENGTH(regexp_substr(p_val, 'S[^//]*'))) -
                ((LENGTH(regexp_substr(p_val, 'S[^//]*'))) - 5));
     begin
       select a.nro_referencia,a.situacion,a.plataforma
       into p_referencia,p_estado,p_plataforma
       from it.ge_snp_transferencias a
       where (a.nro_referencia = v_valor or
              a.nro_ref_externa= v_valor or
              a.nro_lote = v_valor)
       and rownum = 1;
     exception
       when others then
         begin
           select a.nro_referencia,
                  a.situacion,
                  a.plataforma
           into   p_referencia,
                  p_estado,
                  p_plataforma
           from it.ge_snp_transferencias a
           where (a.nro_ref_externa like '%' || v_valor || '%')
           and rownum = 1;
         exception
           when others then
             p_referencia := null;
             p_estado     := null;
             p_plataforma := null;
         end;
     end;

  end pr_recu_datos;

begin
 
  begin  
    delete it.sb_ext_mt940
    where  fecha between p_fec_desde and p_fec_hasta;
  exception
    when others then
    raise_application_error(-20000, 'Al eliminar datos de la tabla SB_EXT_MT940: '||sqlerrm);
  end;

  for i in c_snp_mensajes (p_fec_desde, p_fec_hasta) loop

    v_mt_campo := ':' ||i.campo||':'||i.valor;

    v_fecha     := i.fecha;

    begin
      select distinct (substr(a.valor, 9, 3))
      into   v_moneda
      from   it.sb_snp_mensajes a
      where  a.cod_mensaje          = 'MT940'
      and    a.campo                = '61'
      and    a.nro_linea            = '2'
      and    a.nro_referencia       = i.nro_referencia
      and    trunc(a.fec_insercion) = i.fecha;
    exception
     when others then
       v_moneda := 'PYG';
    end;

    v_tipo  :=  nvl(regexp_substr(i.valor, 'C'), regexp_substr(i.valor, 'D'));

    if v_tipo = 'C' then

      v_monto := rtrim(regexp_substr(rtrim(replace(regexp_substr(i.valor,(regexp_substr(i.valor, 'C')) || '[^S]*'),
                       regexp_substr(i.valor, 'C'),''),','), '[^F]*'),',');

    elsif v_tipo = 'D' then

      v_monto := rtrim(regexp_substr(rtrim(replace(regexp_substr(i.valor,(regexp_substr(i.valor, 'D')) || '[^S]*'),
                       regexp_substr(i.valor, 'D'),''),','), '[^F]*'),',');

    end if;

    v_ref_bcp := nvl(substr(regexp_substr(i.valor, 'S[^//]*'), (length(regexp_substr(i.valor, 'S[^//]*'))) -
               ((length(regexp_substr(i.valor, 'S[^//]*'))) - 5)), 'FTRFNONREF');

    v_tipo_mt := substr(substr(regexp_substr(i.valor, ('S[^//]*')), 1,4),2,3) ;

    pr_recu_datos (i.valor,
                   v_referencia,
                   v_plataforma,
                   v_estado);

    begin
     select case when instr(t.valor,'PYG') > 0  then
              trim(substr(t.valor,instr(t.valor,'PYG')+3,((instr(t.valor,',') - (instr(t.valor,'PYG')+3)))))
            else
              trim(substr(t.valor,instr(t.valor,'USD')+3))
            end
     into   v_sal_ini
     from   it.sb_snp_mensajes t
     where  t.nro_referencia       = i.nro_referencia
     and    trunc(t.fec_insercion) = i.fecha
     and    t.campo                = '60F';
    exception
     when others then
       v_sal_ini := null;
    end;

    begin
      select case when instr(t.valor,'PYG') > 0  then
                 trim(substr(t.valor,instr(t.valor,'PYG')+3,((instr(t.valor,',') - (instr(t.valor,'PYG')+3)))))
            else
                 trim(substr(t.valor,instr(t.valor,'USD')+3))
            end
      into   v_sal_fin
      from   it.sb_snp_mensajes t
      where  t.nro_referencia       = i.nro_referencia
      and    trunc(t.fec_insercion) = i.fecha
      and    t.campo                = '62F';
    exception
      when others then
        v_sal_fin:= null;
    end;

    if v_tipo = 'C' then
      v_ref_consolidada := v_ref_bcp;
    elsif v_tipo = 'D' then
      v_ref_consolidada := v_referencia;
    end if;

    begin
      insert into it.sb_ext_mt940 (mt_campos,
                                 fecha,
                                 moneda,
                                 tipo,
                                 importe,
                                 referencia_bcp,
                                 tipo_mt,
                                 referencia,
                                 ref_consolidada,
                                 plataforma,
                                 estado,
                                 sal_inicial,
                                 sal_final)
                         values (v_mt_campo,
                                 v_fecha,
                                 v_moneda,
                                 v_tipo,
                                 v_monto,
                                 v_ref_bcp,
                                 v_tipo_mt,
                                 v_referencia,
                                 v_ref_consolidada,
                                 v_plataforma,
                                 v_estado,
                                 v_sal_ini,
                                 v_sal_fin);
      commit;
    exception
     when others then
       raise_application_error(-20001, 'Ocurrio un error al registrar datos en SB_EXT_MT940 : '||sqlerrm);
    end;

  end loop;

  for b in c_snp_transferencias (p_fec_desde, p_fec_hasta) loop

    v_mt_campo          := b.mt_campo;
    v_fecha             := b.fecha;
    v_moneda            := b.moneda;
    if v_moneda = 'GS' then
      v_moneda := 'PYG';
    end if;
    v_monto             := b.importe;
    v_tipo              := b.tipo;
    v_ref_bcp           := b.referencia_bcp;
    v_tipo_mt           := b.tipo_mt;
    v_referencia        := b.nro_referencia;
    v_ref_consolidada   := '';
    v_plataforma        := b.plataforma;
    v_estado            := b.situacion;
    v_sal_ini           := b.sal_ini;
    v_sal_fin           := b.sal_fin;

    if v_tipo = 'C' then
      v_ref_consolidada := v_ref_bcp;
    elsif v_tipo = 'D' then
      v_ref_consolidada := v_referencia;
    end if;

    begin
      insert into it.sb_ext_mt940 (mt_campos,
                                 fecha,
                                 moneda,
                                 tipo,
                                 importe,
                                 referencia_bcp,
                                 tipo_mt,
                                 referencia,
                                 ref_consolidada,
                                 plataforma,
                                 estado,
                                 sal_inicial,
                                 sal_final)
                         values (v_mt_campo,
                                 v_fecha,
                                 v_moneda,
                                 v_tipo,
                                 v_monto,
                                 v_ref_bcp,
                                 v_tipo_mt,
                                 v_referencia,
                                 v_ref_consolidada,
                                 v_plataforma,
                                 v_estado,
                                 v_sal_ini,
                                 v_sal_fin);
      commit;
    exception
      when others then
        raise_application_error(-20001, 'Ocurrio un error al registrar datos en SB_EXT_MT940 : '||sqlerrm);
    end;

  end loop;
  
  /* Actualización de Referencias de Reversión */
  
  declare
    cursor c_rev_recibida is
      select a.fec_recepcion, a.nro_referencia, a.nro_ref_externa, a.situacion, a.estado, a.fec_insercion
      from ge_snp_transferencias a
      where a.fec_valor >= p_fec_desde
      and   a.fec_valor <= p_fec_hasta + 10
      and   a.fec_recepcion is null;
   begin
     for a in c_rev_recibida loop
       begin     
         update it.sb_ext_mt940 b
         set    b.nro_ref_rev_recibida = a.nro_referencia
         where  b.referencia_bcp = a.nro_ref_externa
         and    b.nro_ref_rev_recibida is null
         and    rownum = 1;
         commit;
       exception
         when others then
           raise_application_error(-20001, 'Error al actualizar NRO_REF_REV_RECIBIDA. '||sqlerrm);
       end;
     end loop;
   end;

  begin
    merge into it.sb_ext_mt940 a
      using (select t.nro_ref_externa
                   ,replace(replace(trim(substr(t.observacion, (instr(t.observacion, '/REV/')+5),instr(substr(t.observacion, (instr(t.observacion, '/REV/')+5),35),chr(10)))),chr(13),''),chr(10),'') ref_reversion
             from   ge_snp_transferencias t
             where  t.cod_msj_swift = 103
             and    t.fec_recepcion is not null
             and    t.fec_valor >= p_fec_desde
             and    t.fec_valor <= p_fec_hasta + 10
             and    t.observacion like '%/REV/%') b
      on (a.referencia_bcp = b.nro_ref_externa)
      when matched then
        update set a.nro_ref_rev_enviada = b.ref_reversion;
    commit;
  exception
    when others then
      raise_application_error(-20001, 'Error al actualizar NRO_REF_REV_ENVIADA. '||sqlerrm);      
  end;

end;
