create or replace procedure it.prg_mig_per_fisicas_librador is

  cursor per is
    select a.cod_persona,
           a.pri_nombre,
           a.pri_apellido,
           a.est_civil,
           a.cod_sexo,
           a.cod_niv_estudio,
           a.cod_tip_vivienda,
           a.cod_pai_nacionalidad,
           a.seg_nombre,
           a.seg_apellido,
           a.fec_nacimiento,
           a.can_hijos,
           a.cod_profesion,
           a.cod_titulo,
           a.can_personas,
           a.patrimonio,
           a.cod_actividad,
           a.cod_ciu_nacimiento,
           rownum reg
      from it.mi_ba_per_fisicas_librador a
     where cod_persona not in (select cod_persona from ba_per_fisicas);

  v_error    varchar2(100);
  v_err      varchar2(100);
  v_ermsj    varchar2(500);
  v_fecha    date;
  v_cantidad number := 0;
  v_fec      date := pag_cal.fu_obt_fec_actual(1);

begin
  delete mi_logs where proceso = 'PER_FISICAS_LIBRADOR';

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table ba_per_fisicas disable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table ba_personas disable all triggers',
                       v_err);
  --Habilitar trigger
  sql_util.ejecute_dml('alter trigger ta_ba_per_fisicas enable', v_err);

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  for i in per loop
    v_cantidad := v_cantidad + 1;
    begin
      insert into it.ba_per_fisicas
        (cod_persona,
         pri_nombre,
         pri_apellido,
         est_civil,
         cod_sexo,
         cod_niv_estudio,
         cod_tip_vivienda,
         cod_pai_nacionalidad,
         seg_nombre,
         seg_apellido,
         fec_nacimiento,
         can_hijos,
         cod_profesion,
         cod_titulo,
         can_personas,
         patrimonio,
         cod_actividad,
         cod_ciu_nacimiento,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion)
      values
        (i.cod_persona,
         i.pri_nombre,
         i.pri_apellido,
         i.est_civil,
         i.cod_sexo,
         i.cod_niv_estudio,
         i.cod_tip_vivienda,
         i.cod_pai_nacionalidad,
         i.seg_nombre,
         i.seg_apellido,
         i.fec_nacimiento,
         i.can_hijos,
         i.cod_profesion,
         i.cod_titulo,
         i.can_personas,
         i.patrimonio,
         i.cod_actividad,
         i.cod_ciu_nacimiento,
         'MIGRA',
         v_fec,
         'MIGRA',
         v_fec);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        v_fecha := sysdate;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (i.reg,
           v_error,
           v_ermsj,
           i.cod_persona || ' ' || i.pri_nombre || ' ' || i.seg_nombre || ' ' ||
           i.pri_apellido || ' ' || i.seg_apellido,
           'PER_FISICAS_LIBRADOR',
           v_fecha);
    end;

  end loop;
  --Habilitar los triggers
  sql_util.ejecute_dml('alter table ba_per_fisicas enable all triggers',
                       v_err);
  sql_util.ejecute_dml('alter table ba_personas enable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;

exception
  when others then
    v_error := sqlcode;
    v_ermsj := nvl(v_err, sqlerrm);
    v_fecha := sysdate;
    insert into mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    values
      (1, v_error, v_ermsj, 'verif_fisicas', 'PER_FISICAS_LIBRADOR', v_fecha);
    commit;
end;
/
