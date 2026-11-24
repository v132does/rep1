create or replace procedure it.PRT_BLO_AUT_TARJETAS is
      v_consulta   ba_consultas.filtros%type := '';
      v_ref_cursor sql_util.t_cursor_tab;
      v_filas      NUMBER;
      v_error      VARCHAR2(4000);
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);--trunc(sysdate);
      v_semanal    VARCHAR2(1) := 'N';
      v_mensual    VARCHAR2(1) := 'N';
      ---
      rg_ta_blo       ta_blo_aut_tarjetas%rowtype;
      v_cod_modalidad ge_modalidades.cod_modalidad%type;

CURSOR c_consultas IS
   SELECT b.cod_consulta, b.det_sql, b.descripcion
     FROM ba_cod_referencias t, ba_consultas b
    WHERE t.dominio = 'TA_COD_CONSULTAS'
      AND b.cod_consulta = t.significado
    ORDER BY to_number(val_minimo);

FUNCTION lf_ver_gen_mensual RETURN VARCHAR2 IS
  v_existe varchar2(1);
  v_verifica number(3,2) := trunc((to_char(trunc(v_fec_actual),'DD')-fug_obt_pardinamico('FEC_SEMANA'))/7,2);
  BEGIN
    IF v_verifica >= 0 and v_verifica < 1 THEN
      v_existe := 'S';
    ELSE
      v_existe := 'N';
    END IF;
    return v_existe;
  END;

FUNCTION lf_ver_duplicados(p_nro_tarjeta ta_blo_aut_tarjetas.nro_tarjeta%type) RETURN BOOLEAN IS
  v_existe number;
  BEGIN
    select count(*)
      into v_existe
      from ta_blo_aut_tarjetas a
     where a.nro_tarjeta = p_nro_tarjeta
       and exists (select 1 from ta_blo_aut_tarjetas b
                           where b.nro_tarjeta = a.nro_tarjeta--p_nro_tarjeta
                             and b.fecha = v_fec_actual);
    IF v_existe = 0 THEN --no hay duplicaciones
      return true;
    ELSE
      return false;
    END IF;
  END;

--carga el archivo e inserta los registros
PROCEDURE lp_gen_archivo
  (rg_tbata ta_blo_aut_tarjetas%rowtype) is
  v_est_activo varchar2(1) default 'S';
   Begin
     --se busca el estado si está activo 
     -- para informar del bloqueo -- dydmr-8460
       begin
        select distinct 'S'
          into v_est_activo
          from ta_tarjetas a
         where a.nro_tarjeta = rg_tbata.nro_tarjeta
           and a.cod_estado = 6;
       exception
          when no_data_found then
            --buscamos si existe la tarjeta con
            --estado diferente a activo y no informamos del bloqueo
             begin
              select distinct 'N'
                into v_est_activo
                from ta_tarjetas a
               where a.nro_tarjeta = rg_tbata.nro_tarjeta
                 and a.cod_estado != 6;
             exception
               when others then
                v_est_activo := 'S';
             end;
          when others then
            v_est_activo := 'S';
       end;
       ------------------------------------------
       if v_est_activo = 'S' then -- dydmr-8460
         insert into ta_blo_aut_tarjetas
           (fecha, cod_persona, nro_tarjeta, mot_bloqueo,
           cod_accion, tip_bloqueo, tip_operacion, amb_bloqueo,
           for_bloqueo, cod_motivo, usu_actualizacion, mes_purga)
         values
           (rg_tbata.fecha, rg_tbata.cod_persona, rg_tbata.nro_tarjeta, rg_tbata.mot_bloqueo,
           rg_tbata.cod_accion, rg_tbata.tip_bloqueo, rg_tbata.tip_operacion, rg_tbata.amb_bloqueo,
           rg_tbata.for_bloqueo, rg_tbata.cod_motivo, rg_tbata.usu_actualizacion, rg_tbata.mes_purga);
         
         update ta_tarjetas a
            set a.cod_estado = '13'
          where a.nro_tarjeta = rg_tbata.nro_tarjeta;
       end if;
   End;

PROCEDURE lp_gen_tar_adicionales
  (p_nro_cuenta  in ta_cta_tarjetas.nro_cuenta%type) is
   v_cant        number(2);
   v_cod_persona ba_personas.cod_persona%type;
   v_nro_tarjeta ta_tarjetas.nro_tarjeta%type;

   Begin
     begin
       select count(*)
         into v_cant
         from ta_tarjetas a,ge_cta_clientes b
        where a.nro_cuenta = b.nro_cuenta
          and a.cod_persona = b.cod_persona
          and b.relacion != 'P'
          and a.cod_estado = 6
          and a.nro_cuenta = p_nro_cuenta
          and not exists (select 1
                            from ta_tarjetas x, ge_cta_clientes z, ta_blo_aut_tarjetas t
                           where x.nro_tarjeta = a.nro_tarjeta
                             and x.nro_cuenta = z.nro_cuenta
                             and x.cod_persona = z.cod_persona
                             and z.relacion = 'A'
                             and x.cod_persona = t.cod_persona
                             and x.nro_tarjeta = t.nro_tarjeta
                             and t.fecha = v_fec_actual);
     exception
       when no_data_found then
         v_cant := 0;
     end;
     If v_cant > 0 Then
       for i in 1..v_cant loop
         begin
         select a.cod_modalidad,
                b.cod_persona,/*fue_obt_nom_persona(b.cod_persona) nombre,*/
                c.nro_tarjeta
           into v_cod_modalidad, v_cod_persona, /*v_nombre,*/ v_nro_tarjeta
           from ta_cta_tarjetas a, ge_cta_clientes b, ta_tarjetas c
          where a.nro_cuenta = b.nro_cuenta
            and a.cod_modulo = b.cod_modulo
            and a.cod_modalidad = b.cod_modalidad
            and a.nro_cuenta = p_nro_cuenta
            and a.nro_cuenta = c.nro_cuenta
            and b.cod_persona = c.cod_persona
            and c.cod_estado = 6
            and b.relacion = 'A'
            and rownum = 1
            and not exists (select 1
                              from ta_blo_aut_tarjetas x
                             where x.cod_persona = b.cod_persona
                               and x.nro_tarjeta = c.nro_tarjeta
                               and x.fecha = v_fec_actual);
         exception
           when no_data_found then
             raise_application_error(-20000,'Cuenta: '||p_nro_cuenta||' Tarjeta: '||v_nro_tarjeta); --exit;
         end;
         rg_ta_blo.cod_persona       := v_cod_persona;
         rg_ta_blo.nro_tarjeta       := v_nro_tarjeta;
         rg_ta_blo.mot_bloqueo       := 'Adicional de la cuenta '||p_nro_cuenta;
         rg_ta_blo.cod_accion        := fug_obt_pardinamico('COD_ACCION',5,v_cod_modalidad);
         rg_ta_blo.tip_bloqueo       := 'A';
         rg_ta_blo.tip_operacion     := fug_obt_pardinamico('TIP_OPERACION',5,v_cod_modalidad);
         rg_ta_blo.amb_bloqueo       := 'L';
         rg_ta_blo.for_bloqueo       := 'D';
         rg_ta_blo.cod_motivo        := fug_obt_pardinamico('MOT_BLOQUEO',5,v_cod_modalidad);
         rg_ta_blo.usu_actualizacion := fug_obt_pardinamico('USU_BLOQUEO');
         rg_ta_blo.mes_purga         := 998;
         lp_gen_archivo(rg_ta_blo);
       end loop;
     End If;
   End;

BEGIN
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
    --verifica que lunes sea día hábil sino martes
    IF v_fec_actual = pag_cal.FU_OBT_FEC_HABIL(v_fec_actual,1,1) and pag_cal.FU_OBT_NOM_DIA(v_fec_actual) = 'LUNES' THEN
      v_semanal := 'S';
      v_mensual := lf_ver_gen_mensual;--verifica si el 10 cae en la semana
    ELSIF (v_fec_actual = pag_cal.FU_OBT_FEC_HABIL(v_fec_actual,1,1) and pag_cal.FU_OBT_NOM_DIA(v_fec_actual) = 'MARTES')
          and (pag_cal.FU_OBT_NOM_DIA(pag_cal.FU_OBT_FEC_HABIL(v_fec_actual-1,1,1)) != 'LUNES') THEN
      v_semanal := 'S';
      v_mensual := lf_ver_gen_mensual;
    ELSE
      v_semanal := 'N';
    END IF;
    rg_ta_blo.fecha := v_fec_actual;

    FOR i IN c_consultas LOOP
      IF v_semanal = 'S' or v_mensual = 'S' THEN
        v_consulta := i.det_sql;
        v_error := null;
        sql_util.ejecute_consulta(v_consulta, 5, v_filas, v_ref_cursor, v_error);
        --
        if v_error is null then
          FOR j IN 1 .. v_filas LOOP
           if nvl(fug_obt_paradicional(v_ref_cursor(j).columna5,'CTA_DES_AUTORIZADO'),'N') = 'N' then  -- DE-2489
            if lf_ver_duplicados(v_ref_cursor(j).columna4) then --verifica que no inserte doble
               /*
               || Datos de la consulta dinámica
               || -----------------------------
               || v_fec_actual,             --fecha
               || v_ref_cursor(j).columna1, --dato
               || v_ref_cursor(j).columna2, --cod_persona
               || v_ref_cursor(j).columna3, --nombre
               || v_ref_cursor(j).columna4, --nro_tarjeta
               || v_ref_cursor(j).columna5; --nro_cuenta
               || i.descripcion             --mot_bloqueo
               */
               begin
               select cod_modalidad
                 into v_cod_modalidad
                 from ta_cta_tarjetas c
                where c.nro_cuenta = v_ref_cursor(j).columna5;
               exception
                  when no_data_found then
                     raise_application_error(-20001,'Sin modalidad para la cuenta:'||
                                                     v_ref_cursor(j).columna5);
                  when too_many_rows then
                     raise_application_error(-20001,'Mas de 1 modalidad para la cuenta:'||
                                                     v_ref_cursor(j).columna5);
                  when others then
                     raise_application_error(-20001,'Error al Obt.modalidad para la cuenta:'||
                                                     v_ref_cursor(j).columna5||'-'||sqlerrm);
               end;
               rg_ta_blo.cod_persona       := v_ref_cursor(j).columna2;
               rg_ta_blo.nro_tarjeta       := v_ref_cursor(j).columna4;
               rg_ta_blo.mot_bloqueo       := i.descripcion;
               rg_ta_blo.cod_accion        := fug_obt_pardinamico('COD_ACCION',5,v_cod_modalidad);
               rg_ta_blo.tip_bloqueo       := 'A';
               rg_ta_blo.tip_operacion     := fug_obt_pardinamico('TIP_OPERACION',5,v_cod_modalidad);
               rg_ta_blo.amb_bloqueo       := 'L';
               rg_ta_blo.for_bloqueo       := 'D';
               rg_ta_blo.cod_motivo        := fug_obt_pardinamico('MOT_BLOQUEO',5,v_cod_modalidad);
               rg_ta_blo.usu_actualizacion := fug_obt_pardinamico('USU_BLOQUEO');
               rg_ta_blo.mes_purga         := 998;
               lp_gen_archivo(rg_ta_blo);
               lp_gen_tar_adicionales(v_ref_cursor(j).columna5); --nro_cuenta
            end if;
           end if; --- DE-2489
          END LOOP;
        end if;
      END IF;
      exit when v_mensual = 'N';
    END LOOP;
EXCEPTION
  when others then
    raise_application_error(-20000, 'Error en PRT_BLO_AUT_TARJETAS. ' || SQLERRM);
END PRT_BLO_AUT_TARJETAS;
/

