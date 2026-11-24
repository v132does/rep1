create or replace procedure it.PRR_MAT_RIE_CLIENTES_HIS (p_cod_persona varchar2 default null)
is
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(12);
v_cod_puntaje cr_per_puntajes.cod_puntaje%type := fug_obt_pardinamico('COD_PUN_MAT_RIE');
Begin
--Borra historicos si son de la misma fecha que se esta procesando
 begin
    delete from cr_per_puntajes_his
      where to_char(fecha,'DD/MM/YYYY') = to_char(v_fecha,'DD/MM/YYYY')
      and (cod_persona = p_cod_persona or p_cod_persona is null )
      and v_cod_puntaje = cod_puntaje;

    delete from cr_per_pun_elementos_his
      where to_char(fecha,'DD/MM/YYYY') = to_char(v_fecha,'DD/MM/YYYY')
      and (cod_persona = p_cod_persona or p_cod_persona is null )
      and v_cod_puntaje = cod_puntaje;

    delete from cr_pun_personas_his
      where fecha = v_fecha
      and to_char(fecha,'DD/MM/YYYY') = to_char(v_fecha,'DD/MM/YYYY')
      and v_cod_puntaje = cod_puntaje;
  exception
  when others then
  null;
 end;
--Comienza a insertar
  begin
  insert into cr_per_puntajes_his
     select p.*, v_fecha
     from cr_per_puntajes p
     where (cod_persona = p_cod_persona or p_cod_persona is null )
     and cod_puntaje = v_cod_puntaje;
  exception
  when others then
  raise_application_error(-20000,'Error al cargar cr_per_puntajes_his');
  end;
  begin

  insert into cr_pun_personas_his
     (  COD_PERSONA,
        COD_PUNTAJE ,
        COD_CAMPO  ,
        VAL_CAMPO  ,
        PUNTAJE   ,
        USU_INSERCION  ,
        FEC_INSERCION  ,
        USU_MODIFICACION  ,
        FEC_MODIFICACION ,
        FECHA      ,
        COD_GRU_CONCEPTO )
     select p.cod_persona, p.cod_puntaje, p.cod_campo
     , p.val_campo, p.puntaje, p.usu_insercion, p.fec_insercion,
     p.usu_modificacion, p.fec_modificacion,  v_fecha, co.cod_gru_concepto
     from cr_pun_personas p, cr_pun_conceptos co
     where (cod_persona = p_cod_persona or p_cod_persona is null )
     and p.cod_puntaje = v_cod_puntaje
     and p.cod_puntaje = co.cod_puntaje
     and p.cod_campo = co.cod_campo;
  exception
  when others then
  raise_application_error(-20000,'Error al cargar cr_pun_personas_his');
  end;
  begin
  insert into cr_per_pun_elementos_his
     select p.*, v_fecha
     from cr_per_pun_elementos p
     where (cod_persona = p_cod_persona or p_cod_persona is null )
     and cod_puntaje = v_cod_puntaje;
  exception
  when others then
  raise_application_error(-20000,'Error al cargar cr_per_pun_elementos_his');
  end;
end;
/

