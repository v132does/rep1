begin
    execute immediate 'ALTER TABLE IT.GE_SNP_TRANSFERENCIAS MODIFY REF_OID VARCHAR2(1000)';
exception
    when others then
        dbms_output.put_line('Error: ' || sqlerrm);
end;
