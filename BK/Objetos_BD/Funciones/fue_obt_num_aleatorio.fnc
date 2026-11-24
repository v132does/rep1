create or replace function it.fue_obt_num_aleatorio
return integer is
v_numero integer;
begin
  v_numero := sys.dbms_random.random;
  v_numero := abs(v_numero);
  return v_numero;
end;
/

