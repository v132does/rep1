-- Catalogo transacciones FLI/REPO (modulo 10)
-- Destino: homolog uenodesa5 primero; no ejecutar en FINDIA.
-- Padre 102 (copia 127) en 138/139/140.
-- SIPAP 815/816 nuevas (no copiar 741/842). Acuerdo 818/820 en las 3.
-- Interes 819/822 solo 139/140. Garantia 823/824 solo mods de documento.
-- Abreviatura VARCHAR2(6). Descripcion VARCHAR2(60) — hecho de negocio (sin prefijo ticket).
-- Release path: SQL/MDD-91/7001_ins_ge_transacciones.sql

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

declare
  v_ajeno number;
begin
  -- Bloquea si el codigo ya apunta a otro tipo de asiento (otro dueno).
  select count(*)
    into v_ajeno
    from it.ge_transacciones
   where cod_modulo = 10
     and (
           (cod_modalidad in (138, 139, 140)
            and cod_transaccion = 818
            and nvl(cod_tip_asiento, 9901) <> 9901)
        or (cod_modalidad in (138, 139, 140)
            and cod_transaccion = 820
            and nvl(cod_tip_asiento, 9903) <> 9903)
        or (cod_modalidad in (139, 140)
            and cod_transaccion = 819
            and nvl(cod_tip_asiento, 9902) <> 9902)
        or (cod_modalidad in (139, 140)
            and cod_transaccion = 822
            and nvl(cod_tip_asiento, 9904) <> 9904)
        or (cod_modalidad in (101, 105, 106, 123, 125, 129)
            and cod_transaccion = 823
            and nvl(cod_tip_asiento, 9908) <> 9908)
        or (cod_modalidad in (101, 105, 106, 123, 125, 129)
            and cod_transaccion = 824
            and nvl(cod_tip_asiento, 9909) <> 9909)
         );

  if v_ajeno > 0 then
    raise_application_error(-20092,
      'Catalogo FLI/REPO: transaccion 815-824 ocupada con un tipo de asiento distinto al catalogo.');
  end if;
end;
/

-- Padre 102 VTADOC: copia 127 en 138/139/140
insert into it.ge_transacciones (
  cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo,
  abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, cod_tasa, batch,
  cod_retencion, interno, afecta, cod_tip_asiento2, detallado,
  cod_tip_asi_resultado, tip_despliegue)
select t.cod_transaccion, 10, m.cod_modalidad, t.descripcion, t.ve_cliente, t.tipo,
       t.abreviatura, t.rutina1, t.rutina2, t.rutina3, t.cod_tip_asiento, t.cod_tasa,
       t.batch, t.cod_retencion, t.interno, t.afecta, t.cod_tip_asiento2, t.detallado,
       t.cod_tip_asi_resultado, t.tip_despliegue
  from (select 138 cod_modalidad from dual
        union all select 139 from dual
        union all select 140 from dual) m
 cross join it.ge_transacciones t
 where t.cod_modulo = 10
   and t.cod_modalidad = 127
   and t.cod_transaccion = 102
   and not exists (
         select 1 from it.ge_transacciones x
          where x.cod_modulo = 10
            and x.cod_modalidad = m.cod_modalidad
            and x.cod_transaccion = 102);

-- Producto: 815/816/818/820 en 138/139/140; 819/822 solo 139/140
merge into it.ge_transacciones dst
using (
  select m.cod_modalidad, s.cod_transaccion, s.descripcion, s.ve_cliente, s.tipo,
         s.abreviatura, s.batch, s.detallado, s.cod_tip_asiento, s.afecta
    from (select 138 cod_modalidad from dual
          union all select 139 from dual
          union all select 140 from dual) m
   cross join (
          select 815 cod_transaccion, 'LIQUIDACION SIPAP ALTA' descripcion,
                 'N' ve_cliente, 'D' tipo, 'LISIAL' abreviatura, 'O' batch, 'S' detallado,
                 to_number(null) cod_tip_asiento, 'N' afecta from dual
          union all
          select 816, 'LIQUIDACION SIPAP BAJA', 'S', 'D', 'LISIBA', 'O', 'S',
                 to_number(null), 'N' from dual
          union all
          select 818, 'ALTA ACUERDO DEAL', 'S', 'C', 'ALACDE', 'B', 'N',
                 9901, 'N' from dual
          union all
          select 820, 'BAJA ACUERDO DEAL', 'S', 'D', 'BAACDE', 'B', 'N',
                 9903, 'N' from dual
        ) s
   union all
  select m.cod_modalidad, s.cod_transaccion, s.descripcion, s.ve_cliente, s.tipo,
         s.abreviatura, s.batch, s.detallado, s.cod_tip_asiento, s.afecta
    from (select 139 cod_modalidad from dual
          union all select 140 from dual) m
   cross join (
          select 819 cod_transaccion, 'ALTA INTERES' descripcion,
                 'S' ve_cliente, 'C' tipo, 'ALTINT' abreviatura, 'B' batch, 'N' detallado,
                 9902 cod_tip_asiento, 'N' afecta from dual
          union all
          select 822, 'BAJA INTERES', 'S', 'C', 'BAJINT', 'B', 'N',
                 9904, 'N' from dual
        ) s
) src
on (dst.cod_modulo = 10
    and dst.cod_modalidad = src.cod_modalidad
    and dst.cod_transaccion = src.cod_transaccion)
when matched then update set
  dst.descripcion     = src.descripcion,
  dst.ve_cliente      = src.ve_cliente,
  dst.tipo            = src.tipo,
  dst.abreviatura     = src.abreviatura,
  dst.rutina1         = null,
  dst.rutina2         = null,
  dst.rutina3         = null,
  dst.cod_tip_asiento = src.cod_tip_asiento,
  dst.batch           = src.batch,
  dst.interno         = 'N',
  dst.afecta          = src.afecta,
  dst.cod_tip_asiento2 = null,
  dst.detallado       = src.detallado,
  dst.cod_tip_asi_resultado = null,
  dst.usu_modificacion = substr(user, 1, 10),
  dst.fec_modificacion = sysdate
when not matched then insert (
  cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo,
  abreviatura, rutina1, rutina2, rutina3, cod_tip_asiento, batch, interno,
  afecta, detallado)
values (
  src.cod_transaccion, 10, src.cod_modalidad, src.descripcion, src.ve_cliente,
  src.tipo, src.abreviatura, null, null, null, src.cod_tip_asiento, src.batch,
  'N', src.afecta, src.detallado);

-- Garantia 823/824: solo modalidades de documento (823P provisional)
merge into it.ge_transacciones dst
using (
  select m.cod_modalidad, s.cod_transaccion, s.descripcion, s.tipo, s.abreviatura,
         s.cod_tip_asiento
    from (select 101 cod_modalidad from dual
          union all select 105 from dual
          union all select 106 from dual
          union all select 123 from dual
          union all select 125 from dual
          union all select 129 from dual) m
   cross join (
          select 823 cod_transaccion, 'ALTA GARANTIA' descripcion,
                 'D' tipo, 'ALTGAR' abreviatura, 9908 cod_tip_asiento from dual
          union all
          select 824, 'BAJA GARANTIA', 'C', 'BAJGAR', 9909 from dual
        ) s
) src
on (dst.cod_modulo = 10
    and dst.cod_modalidad = src.cod_modalidad
    and dst.cod_transaccion = src.cod_transaccion)
when matched then update set
  dst.descripcion     = src.descripcion,
  dst.ve_cliente      = 'S',
  dst.tipo            = src.tipo,
  dst.abreviatura     = src.abreviatura,
  dst.rutina1         = null,
  dst.cod_tip_asiento = src.cod_tip_asiento,
  dst.batch           = 'B',
  dst.interno         = 'N',
  dst.afecta          = 'N',
  dst.detallado       = 'N',
  dst.usu_modificacion = substr(user, 1, 10),
  dst.fec_modificacion = sysdate
when not matched then insert (
  cod_transaccion, cod_modulo, cod_modalidad, descripcion, ve_cliente, tipo,
  abreviatura, rutina1, cod_tip_asiento, batch, interno, afecta, detallado)
values (
  src.cod_transaccion, 10, src.cod_modalidad, src.descripcion, 'S', src.tipo,
  src.abreviatura, null, src.cod_tip_asiento, 'B', 'N', 'N', 'N');

commit;
/
